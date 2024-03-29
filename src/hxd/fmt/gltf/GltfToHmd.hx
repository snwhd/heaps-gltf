package hxd.fmt.gltf;

import hxd.fmt.gltf.GltfData;


typedef NodeAnimationInfo = {
    var rotation: Array<Float>;
    var scale: Array<Float>;
    var translation: Array<Float>;
    var weights: Array<Float>;
    var hmdObject: hxd.fmt.hmd.Data.AnimationObject;
}


typedef GeometryInfo = {
    var hmdGeometries: Array<hxd.fmt.hmd.Data.Geometry>;
    var geometryMaterials: Array<Array<Int>>;
    var meshToGeometry: Array<Array<Int>>;
}


typedef MaterialInfo = {
    var hmdMaterials: Array<hxd.fmt.hmd.Data.Material>;
}


typedef ModelInfo = {
    var hmdModels: Array<hxd.fmt.hmd.Data.Model>;
}


typedef AnimationInfo = {
    var hmdAnimations: Array<hxd.fmt.hmd.Data.Animation>;
}


class GltfToHmd {

    private static inline var ANIMATION_SAMPLE_RATE = 60.0;

    public var filename: String;
    public var directory: String;
    public var reldirectory: String;
    public var bytes: Null<haxe.io.Bytes>;
    public var gltf: GltfData;

    // Keep high precision values.
    // Might increase animation data size and compressed size.
    public var highPrecision : Bool = false;

    public function new(
        filename: String,
        directory: String,    // relative to execution
        reldirectory: String, // relative to resource dir
        textChunk: String,
        ?bytes: haxe.io.Bytes
    ): Void {
        this.filename = filename;
        this.directory = directory;
        this.reldirectory = reldirectory;
        this.bytes = bytes;
        this.gltf = haxe.Json.parse(textChunk);
    }

    // Util for reading all the data pointed to by an accessor.
    private inline function readWholeBuffer(bufferView: Int): haxe.io.Bytes {
        var view = this.gltf.bufferViews[bufferView];
        var buffer = this.gltf.buffers[view.buffer];
        return AccessorUtil.readBufferView(
            view,
            buffer,
            this.bytes,
            this.directory
        );
    }

    //
    // Create one `hxd.fmt.hmd.Geometry` for every primitive of every mesh, and
    // write their postiions, normals, tangents, weights, and joints
    // and indices to `out`.
    //
    // TODO: glTF files may contain multiple primitives with identical lists of
    //       accessors, meaning they have the same positions, normals, uvs,
    //       tangents, joints, and weights (but not necessarily the same
    //       indices or material). There is still some optimization to be done
    //       for this sceario (which is done in v1).
    //
    private function writeGeometries(out: BytesWriter): GeometryInfo {
        var hmdGeometries: Array<hxd.fmt.hmd.Data.Geometry> = [];
        var geometryMaterials: Array<Array<Int>> = [];
        var meshToGeometry: Array<Array<Int>> = [];

        for (meshIndex => mesh in this.gltf.meshes.keyValueIterator()) {

            var meshGeoList = [];
            meshToGeometry.push(meshGeoList);

            for (prim in mesh.primitives) {
                if (prim.mode != null && prim.mode != TRIANGLES) {
                    throw "TODO: non-triangle prims";
                }

                var primDataStart = out.length;
                var bounds = new h3d.col.Bounds();
                bounds.empty();

                var posAcc = this.getPrimAccessor(prim, "POSITION");
                var norAcc = this.getPrimAccessor(prim, "NORMAL");
                var texAcc = this.getPrimAccessor(prim, "TEXCOORD_0");
                var tanAcc = this.getPrimAccessor(prim, "TANGENT");
                var jointAcc = this.getPrimAccessor(prim, "JOINTS_0");
                var weightAcc = this.getPrimAccessor(prim, "WEIGHTS_0");

                if (norAcc == null && prim.indices != null) {
                    throw "generated normals on indexed geos is not supported";
                }
                if ((jointAcc == null) != (weightAcc == null)) {
                    throw "joints/weights mismatch";
                }

                // indices cannot exceed attributes count, which must all
                // be equal.
                var indices: Array<Int> = [];
                indices.resize(posAcc.count);

                if (prim.indices != null) {
                    var indAcc = this.getAccessor(prim.indices);
                    for (i in 0 ... indAcc.count) {
                        indices[i] = indAcc.index(i);
                    }
                } else {
                    // generate default indices
                    //   > When indices property is not defined, the number of
                    //   > vertex indices to render is defined by count of
                    //   > attribute accessors (with the implied values from
                    //   > range [0..count))
                    for (i in 0 ... posAcc.count) {
                        indices[i] = i;
                    }
                }

                // generate normals if not provided
                var generatedNormals = null;
                if (norAcc == null) {
                    generatedNormals = this.generateNormals(posAcc);
                }

                // generated tangents if not provided
                // TODO: option to force generate tangents?
                var generatedTangents = null;
                if (tanAcc == null) {
                    generatedTangents = this.generateTangents(
                        posAcc,
                        norAcc,
                        texAcc,
                        indices,
                        generatedNormals
                    );
                }

                // write data for each vertex
                for (i in 0 ... posAcc.count) {

                    // positions
                    var x = posAcc.float(i, 0);
                    var y = posAcc.float(i, 1);
                    var z = posAcc.float(i, 2);
                    out.writeFloat(x);
                    out.writeFloat(y);
                    out.writeFloat(z);
                    bounds.addPos(x, y, z);

                    // normals
                    if (norAcc != null) {
                        norAcc.copyFloats(out, i, 3);
                    } else if (generatedNormals != null) {
                        var norm = generatedNormals[Std.int(i/3)];
                        out.writeFloat(norm.x);
                        out.writeFloat(norm.y);
                        out.writeFloat(norm.z);
                    } else throw "missing normals";

                    // tangents
                    if (tanAcc != null) {
                        tanAcc.copyFloats(out, i, 3);
                    } else if (generatedTangents != null) {
                        var index = i * 4;
                        out.writeFloat(generatedTangents[index++]);
                        out.writeFloat(generatedTangents[index++]);
                        out.writeFloat(generatedTangents[index]);
                    } else throw "missing tangents";

                    // uvs
                    if (texAcc != null) {
                        texAcc.copyFloats(out, i, 2);
                    } else {
                        out.writeFloat(0.5);
                        out.writeFloat(0.5);
                    }

                    // joints & weights
                    if (jointAcc != null) {
                        for (jIndex in 0 ... 4) {
                            var joint = jointAcc.int(i, jIndex);
                            if (joint < 0) throw "negative joint index";
                            out.writeByte(joint);
                        }

                        // write weights. We only write 3 of the 4 weights here,
                        // as the heaps skin shader will calculate the fourth as
                        // needed with: var w = 1 - (x + y + z);
                        for (wIndex in 0 ... 3) {
                            var weight = weightAcc.float(i, wIndex);
                            if (Math.isNaN(weight)) throw "weight is NaN";
                            out.writeFloat(weight);
                        }
                    }
                }

                // create the actual geometry data
                var geometry = new hxd.fmt.hmd.Data.Geometry();
                var mats = [];

                // TODO: this is just 0 ... length?
                meshGeoList.push(hmdGeometries.length);

                geometryMaterials.push(mats);
                hmdGeometries.push(geometry);

                geometry.props = null;
                geometry.vertexCount = posAcc.count;

                // build vertex format
                var format = [
                    new hxd.fmt.hmd.Data.GeometryFormat("position", DVec3),
                    new hxd.fmt.hmd.Data.GeometryFormat("normal", DVec3),
                    new hxd.fmt.hmd.Data.GeometryFormat("tangent", DVec3),
                    new hxd.fmt.hmd.Data.GeometryFormat("uv", DVec2),
                ];
                if (jointAcc != null) {
                    format.push(new hxd.fmt.hmd.Data.GeometryFormat("indexes", DBytes4));
                    format.push(new hxd.fmt.hmd.Data.GeometryFormat("weights", DVec3));
                }

                geometry.vertexFormat = hxd.BufferFormat.make(format);
                geometry.vertexPosition = primDataStart;
                geometry.bounds = bounds;

                if (prim.material != null) {
                    mats.push(prim.material);
                }

                geometry.indexPosition = out.length;
                geometry.indexCounts = [indices.length];
                if (geometry.vertexCount > 0x10000) {
                    for (i in indices) {
                        out.writeInt32(i);
                    }
                } else {
                    for (i in indices) {
                        out.writeUInt16(i);
                    }
                }
            }
        }

        return {
            hmdGeometries: hmdGeometries,
            geometryMaterials: geometryMaterials,
            meshToGeometry: meshToGeometry,
        };
    }

    //
    // Create hmd materials 1:1 for glTF materials. glTF supports many material
    // options that are not in HMD, which only has references to material files.
    // Adding support for these options (e.g. solid colors, glb embedded
    // materials, and metallic/roughness) require changes on the heaps side.
    // Solid color is supported via a macro hack.
    //
    private function writeMaterials(out: BytesWriter): MaterialInfo {
        var hmdMaterials: Array<hxd.fmt.hmd.Data.Material> = [];

        for (matIdx => material in this.gltf.materials.keyValueIterator()) {
            var hmdMaterial = new hxd.fmt.hmd.Data.Material();
            hmdMaterial.name = material.name;

            var pbr = material.pbrMetallicRoughness;
            if (pbr != null && pbr.baseColorTexture != null) {
                var bcTexture = pbr.baseColorTexture;
                var coord = bcTexture.texCoord == null
                    ? 0
                    : bcTexture.texCoord;
                if (coord != 0) {
                    throw "TODO: nonzero texcoord";
                }

                if (this.gltf.textures == null) {
                    throw "missing requried texture info";
                }
                var texture = this.gltf.textures[bcTexture.index];
                if (texture.source == null) {
                    // texture defines a pbr texture, but that source is null:
                    //
                    // > implementations may render such textures with a
                    // > predefined placeholder image or being filled with some
                    // > error color (usually magenta).
                    //

                    #if !heaps_gltf_disable_material_patch
                    // solid color textures are only supported if using the
                    // heaps material patch:
                    hmdMaterial.diffuseTexture = "#FF00FF";
                    hmdMaterial.blendMode = None;
                    hmdMaterials.push(hmdMaterial);
                    continue;
                    #else
                    // solid color not supported - throw
                    throw "material uses texture with undefined source";
                    #end
                }

                var image = this.gltf.images[texture.source];

                if (image.uri != null) {
                    if (StringTools.startsWith(image.uri, "http")) {
                        throw "TODO";
                    }

                    hmdMaterial.diffuseTexture = haxe.io.Path.join([
                        // needs to be relative to res dir
                        this.reldirectory,
                        StringTools.urlDecode(image.uri)
                    ]);
                } else if (image.bufferView != null) {
                    var ext = switch (image.mimeType) {
                        case "image/png": "PNG";
                        case "image/jpeg": "JPG";
                        case s: throw 'unknown image format: $s';
                    }

                    // TODO: bundle these and move to the end?
                    // append inline images to binary data
                    var start = out.length;
                    var bufferView = this.gltf.bufferViews[image.bufferView];
                    var length = bufferView.byteLength;
                    hmdMaterial.diffuseTexture = '$ext@$start--$length';
                    out.writeBytes(
                        this.readWholeBuffer(image.bufferView),
                        0,
                        length
                    );

                    // inlineImages.push({
                    //     buf: image.bufferView.buffer,
                    //     pos: image.bufferView.byteOffset,
                    //     len: image.bufferView.byteLength,
                    //     mat: matIdx,
                    //     ext: ext,
                    // });
                } else {
                    throw "material imagem ust have buffer or uri";
                }
            #if !heaps_gltf_disable_material_patch
            } else if (pbr != null && pbr.baseColorFactor != null) {
                var baseColor = material.pbrMetallicRoughness.baseColorFactor;
                if (baseColor.length < 3) {
                    throw "invalid material color";
                }
                hmdMaterial.diffuseTexture = Util.toColorString(
                    h3d.Vector4.fromArray(baseColor).toColor()
                );
            } else {
                hmdMaterial.diffuseTexture = Util.toColorString(0);
            #end
            }

            // note: this code is duplicated above, at the early return if
            // texture source is null
            hmdMaterial.blendMode = None;
            hmdMaterials.push(hmdMaterial);
        }

        return {
            hmdMaterials: hmdMaterials,
        };
    }

    //
    // Create a root hmd Model, and one for each non-joint gltf node.
    //
    private function writeModels(
        geoInfo: GeometryInfo,
        out: BytesWriter
    ): ModelInfo {
        var identityPos = new hxd.fmt.hmd.Data.Position();
        Util.initializePosition(identityPos);

        var root = new hxd.fmt.hmd.Data.Model();
        root.name = this.filename;
        root.props = null;
        root.parent = -1;
        root.follow = null;
        root.position = identityPos;
        root.skin = null;
        root.geometry = -1;
        root.materials = null;

        var hmdModels: Array<hxd.fmt.hmd.Data.Model> = [];
        hmdModels.push(root);

        // identify joints
        var jointNodes: Map<Int, Bool> = [];
        if (this.gltf.skins != null) for (skin in this.gltf.skins) {
            for (jointIndex in skin.joints) {
                jointNodes[jointIndex] = true;
            }
        }

        // checks that all joint children are also joints.
        // TODO: support non-joint children
        function checkJoints(i: Int) {
            var node = this.gltf.nodes[i];
            if (node.mesh != null) throw "joints with meshes not supported";
            if (node.children != null) for (child in node.children) {
                checkJoints(child);
            }
        }

        var modelCount = hmdModels.length;
        // map from a node to its parent
        var nodeParents: Map<Int, Int> = [];
        // map from a node to its index in hmdModels
        var outputIndices: Map<Int, Int> = [];

        for (nodeIndex => node in this.gltf.nodes.keyValueIterator()) {
            if (jointNodes.exists(nodeIndex)) {
                checkJoints(nodeIndex);
            } else {
                outputIndices[nodeIndex] = modelCount++;
            }
            if (node.children != null) {
                for (child in node.children) {
                    if (nodeParents.exists(child)) throw "duplicate node parent";
                    nodeParents[child] = nodeIndex;
                }
            }
        }
        hmdModels.resize(modelCount);

        for (nodeIndex => node in this.gltf.nodes.keyValueIterator()) {
            if (jointNodes.exists(nodeIndex)) continue;

            var parent = nodeParents.get(nodeIndex);
            if (parent != null) {
                parent = outputIndices[parent];
            } else {
                parent = 0;
            }

            var hmdModel = new hxd.fmt.hmd.Data.Model();
            hmdModel.name = node.name;
            hmdModel.props = null;
            hmdModel.parent = parent;
            hmdModel.follow = null;
            hmdModel.position = this.nodeToPos(node);
            hmdModel.skin = null;

            hmdModel.geometry = -1;
            hmdModel.materials = null;
            if (node.mesh != null) {
                if (node.skin != null) {
                    hmdModel.skin = this.buildSkin(
                        nodeParents,
                        this.gltf.skins[node.skin],
                        node.name
                    );
                }

                var geometries = geoInfo.meshToGeometry[node.mesh];
                if (geometries.length == 1) {
                    // we can put a single geometry into the node
                    hmdModel.geometry = geometries[0];
                    hmdModel.materials = geoInfo.geometryMaterials[hmdModel.geometry];
                } else for (geometryIndex in geometries) {
                    // model per primitive
                    var primModel = new hxd.fmt.hmd.Data.Model();
                    primModel.name = this.gltf.meshes[node.mesh].name;
                    primModel.props = null;
                    primModel.parent = outputIndices[nodeIndex];
                    primModel.position = identityPos;
                    primModel.follow = null;
                    primModel.skin = null;
                    primModel.geometry = geometryIndex;
                    primModel.materials = geoInfo.geometryMaterials[geometryIndex];
                    hmdModels.push(primModel);
                }
            }

            var idx = outputIndices[nodeIndex];
            if (idx == null) {
                throw 'invalid model index: $nodeIndex';
            } if (hmdModels[idx] != null) {
                throw 'overwriting model $idx';
            }
            hmdModels[idx] = hmdModel;
        }

        return {
            hmdModels: hmdModels,
        };
    }

    // Create hmd animation object 1:1 for each gltf animation
    private function writeAnimations(
        modelInfo: ModelInfo,
        out: BytesWriter
    ): AnimationInfo {
        var hmdAnimations: Array<hxd.fmt.hmd.Data.Animation> = [];
        if (this.gltf.animations != null) for (anim in this.gltf.animations) {
            var hmdAnimation = new hxd.fmt.hmd.Data.Animation();
            hmdAnimation.name = anim.name;
            hmdAnimation.props = null;
            hmdAnimation.sampling = ANIMATION_SAMPLE_RATE;
            hmdAnimation.speed = 1.0;
            hmdAnimation.loop = false;
            hmdAnimation.objects = [];

            //
            // parse data from gltf channels
            //

            // used to calculate length & number of frames
            var start = Math.POSITIVE_INFINITY;
            var end = Math.NEGATIVE_INFINITY;

            for (channel in anim.channels) {
                var sampler = anim.samplers[channel.sampler];
                var accessor = this.gltf.accessors[sampler.input];
                if (accessor.max != null) {
                    end = Math.max(end, accessor.max[0]);
                }
                if (accessor.min != null) {
                    start = Math.min(start, accessor.min[0]);
                }
            }

            // calculate number of frames
            var length = end - start;
            hmdAnimation.frames = Std.int((end - start) * ANIMATION_SAMPLE_RATE);

            function sampleCurve(
                sampId: Int,
                numComps: Int,
                isQuat: Bool
            ): Array<Float> {
                var samp = anim.samplers[sampId];
                var inAcc = this.getAccessor(samp.input);
                var outAcc = this.getAccessor(samp.output);
                if (outAcc.typeSize != numComps) {
                    throw "numComps mismatch";
                }
                var values = new Array();
                values.resize(hmdAnimation.frames*outAcc.typeSize);
                var vals0 = new Array();
                vals0.resize(numComps);
                var vals1 = new Array();
                vals1.resize(numComps);
                for (f in 0...hmdAnimation.frames) {
                    var time = start + f*(1/Data.SAMPLE_RATE);
                    var samp = this.interpAnimSample(inAcc, time);
                    if (samp.ind1 == -1) {
                        for (i in 0...numComps) {
                            values[f*numComps+i] = outAcc.float(
                                samp.ind0,
                                i
                            );
                        }
                        continue;
                    }
                    // Otherwise fill up the two values and interpolate
                    for (i in 0...numComps) {
                        vals0[i] = outAcc.float(
                            samp.ind0,
                            i
                        );
                        vals1[i] = outAcc.float(
                            samp.ind1,
                            i
                        );
                    }
                    if (!isQuat) {
                        // Simple lerp
                        for (i in 0...numComps) {
                            var v1 = vals0[i] * samp.weight;
                            var v0 = vals1[i] * (1.0 - samp.weight);
                            values[f*numComps+i] = v0 + v1;
                        }
                    } else {
                        if (numComps != 4) throw "numComps != 4";
                        // Quaternion weirdness
                        var q0 = new h3d.Quat(
                            vals0[0],
                            vals0[1],
                            vals0[2],
                            vals0[3]
                        );
                        var q1 = new h3d.Quat(
                            vals1[0],
                            vals1[1],
                            vals1[2],
                            vals1[3]
                        );

                        q0.lerp(q0, q1, samp.weight, true);
                        values[f*numComps + 0] = q0.x;
                        values[f*numComps + 1] = q0.y;
                        values[f*numComps + 2] = q0.z;
                        values[f*numComps + 3] = q0.w;
                    }

                }
                return values;
            }

            function newNodeAnimationInfo(name: String) {
                var anim =  new hxd.fmt.hmd.Data.AnimationObject();
                anim.flags = new haxe.EnumFlags();
                anim.name = name;
                anim.props = [];
                return {
                    rotation: null,
                    scale: null,
                    translation: null,
                    weights: null,
                    hmdObject: anim,
                };
            }

            // mape from node index to animation values
            var nodeAnimationMap: Map<Int, NodeAnimationInfo> = [];
            var targetOrder: Array<Int> = [];

            for (channel in anim.channels) {

                // TODO: warn on missing target?
                if (channel.target.node == null) continue;
                var target = this.gltf.nodes[channel.target.node];

                //
                // extract animation curves for each node
                //

                var targetNodeIndex = channel.target.node;
                var info = nodeAnimationMap.get(targetNodeIndex);
                if (info == null) {
                    // create a new info/curve
                    info = newNodeAnimationInfo(target.name);
                    nodeAnimationMap[targetNodeIndex] = info;
                    targetOrder.push(targetNodeIndex);

                    // save to output object
                    hmdAnimation.objects.push(info.hmdObject);
                }

                switch (channel.target.path) {
                    case "translation":
                        if (info.translation != null) {
                            throw "multiple translations";
                        }
                        info.translation = sampleCurve(
                            channel.sampler,
                            3,
                            false
                        );
                        info.hmdObject.flags.set(HasPosition);
                    case "rotation":
                        if (info.rotation != null) throw "multiple rotations";
                        info.rotation = sampleCurve(
                            channel.sampler,
                            4,
                            true
                        );
                        info.hmdObject.flags.set(HasRotation);
                    case "scale":
                        if (info.scale != null) throw "multiple scales";
                        info.scale = sampleCurve(
                            channel.sampler,
                            3,
                            false
                        );
                        info.hmdObject.flags.set(HasScale);
                    case "weights":
                        if (info.weights != null) throw "multiple weights";
                        throw "TODO: weights";
                        // info.weights = sampleCurve(channel.sampler, 3, false);
                        // info.hmdObject.flags.set(HasWeights);
                }
            }

            //
            // write frame data
            //

            hmdAnimation.dataPosition = out.length;
            for (frameIndex in 0 ... hmdAnimation.frames) {
                for (targetNodeIndex in targetOrder) {
                    var info = nodeAnimationMap[targetNodeIndex];

                    if (info.translation != null) {
                        var index = frameIndex * 3;
                        out.writeFloat(info.translation[index++]);
                        out.writeFloat(info.translation[index++]);
                        out.writeFloat(info.translation[index]);
                    }

                    if (info.rotation != null) {
                        var index = frameIndex * 4;
                        var quat = new h3d.Quat(
                            info.rotation[index++],
                            info.rotation[index++],
                            info.rotation[index++],
                            info.rotation[index]
                        );
                        if (Math.abs(quat.length() - 1.0) >= 0.2) {
                            throw "invalid animation curve";
                        }

                        quat.normalize();
                        if (quat.w < 0) {
                            out.writeFloat(-quat.x);
                            out.writeFloat(-quat.y);
                            out.writeFloat(-quat.z);
                        } else {
                            out.writeFloat(quat.x);
                            out.writeFloat(quat.y);
                            out.writeFloat(quat.z);
                        }

                        if (info.scale != null) {
                            var index = frameIndex * 3;
                            out.writeFloat(info.scale[index++]);
                            out.writeFloat(info.scale[index++]);
                            out.writeFloat(info.scale[index]);
                        }
                    }
                }
            }

            hmdAnimations.push(hmdAnimation);
        }

        return {
            hmdAnimations: hmdAnimations,
        };
    }

    private function buildHMD(
        geoInfo: GeometryInfo,
        matInfo: MaterialInfo,
        modelInfo: ModelInfo,
        animInfo: AnimationInfo,
        bytes: BytesWriter
    ): hxd.fmt.hmd.Data.Data {
        var data = new hxd.fmt.hmd.Data.Data();
        #if hmd_version
        data.version = Std.parseInt(
            #if macro
            haxe.macro.Context.definedValue("hmd_version")
            #else
            haxe.macro.Comiler.getDefine("hmd_version")
            #end
        );
        #else
        data.version = hxd.fmt.hmd.Data.CURRENT_VERSION;
        #end

        data.props = null;
        data.models = modelInfo.hmdModels;
        data.materials = matInfo.hmdMaterials;
        data.geometries = geoInfo.hmdGeometries;
        data.animations = animInfo.hmdAnimations;
        data.dataPosition = 0;
        data.data = bytes.getBytes();
        return data;
    }

    // Estimate output size based on sum of buffer lengths, to avoid
    // allocations during writing.
    private function allocateOutputWriter(): BytesWriter {
        var sizeEstimate = 0;
        for (buffer in this.gltf.buffers) {
            sizeEstimate += buffer.byteLength;
        }
        sizeEstimate = Std.int(sizeEstimate * 1.25);
        return new BytesWriter(sizeEstimate, Std.int(sizeEstimate*0.25));
    }

    public function toHMD(): hxd.fmt.hmd.Data.Data {
        var out = this.allocateOutputWriter();
        var geo = this.writeGeometries(out);
        var mat = this.writeMaterials(out);
        var model = this.writeModels(geo, out);
        var anim = this.writeAnimations(model, out);
        return this.buildHMD(geo, mat, model, anim, out);
    }

    // Generate normals based on given positions.
    // TODO: support indexed prims
    private inline function generateNormals(posAcc: AccessorUtil): Array<h3d.Vector> {
        if (posAcc.count % 3 != 0) throw "bad position accessor length";
        var numTris = Std.int(posAcc.count / 3);
        var ret = [];

        for (i in 0...numTris) {
            var ps = [];
            for (p in 0 ... 3) {
                ps.push(new h3d.Vector(
                    posAcc.float(i*3 + p, 0),
                    posAcc.float(i*3 + p, 1),
                    posAcc.float(i*3 + p, 2)
                ));
            }
            var d0 = ps[1].sub(ps[0]);
            var d1 = ps[2].sub(ps[1]);
            ret.push(d0.cross(d1));
        }

        return ret;
    }

    // Generate tangents with mikktspace.
    private inline function generateTangents(
        posAcc: AccessorUtil,
        norAcc: AccessorUtil,
        texAcc: AccessorUtil,
        indices: Array<Int>,
        genNormals: Array<h3d.Vector>
    ): Array<Float> {
        if (norAcc == null && genNormals == null) throw "no normals provided";

        #if (hl && !hl_disable_mikkt && (haxe_ver >= "4.0"))
        return this.generateTangentsHL(
            posAcc,
            norAcc,
            texAcc,
            indices,
            genNormals
        );
        #elseif (sys || nodejs)
        return this.generateTangentsSystem(
            posAcc,
            norAcc,
            texAcc,
            indices,
            genNormals
        );
        #else
        throw "tangent generation is not supported on this platform";
        #end
    }

    #if (hl && !hl_disable_mikkt && (haxe_ver >= "4.0"))
    private inline function generateTangentsHL(
        posAcc: AccessorUtil,
        norAcc: AccessorUtil,
        texAcc: AccessorUtil,
        indices: Array<Int>,
        genNormals: Array<h3d.Vector>
    ): Array<Float> {
        if (norAcc == null && genNormals == null) throw "no normals provided";

        var m = new hl.Format.Mikktspace();
        m.buffer = new hl.Bytes(8 * 4 * indices.length);
        m.stride = 8;
        m.xPos = 0;
        m.normalPos = 3;
        m.uvPos = 6;

        m.indexes = new hl.Bytes(4 * indices.length);
        m.indices = indices.length;

        m.tangents = new hl.Bytes(4 * 4 * indices.length);
        (m.tangents:hl.Bytes).fill(0,4 * 4 * indices.length,0);
        m.tangentStride = 4;
        m.tangentPos = 0;

        var out = 0;
        for (i in 0 ... indices.length) {
            var vidx = indices[i];
            m.buffer[out++] = posAcc.float(vidx, 0);
            m.buffer[out++] = posAcc.float(vidx, 1);
            m.buffer[out++] = posAcc.float(vidx, 2);

            if (norAcc != null) {
                m.buffer[out++] = norAcc.float(vidx, 0);
                m.buffer[out++] = norAcc.float(vidx, 1);
                m.buffer[out++] = norAcc.float(vidx, 2);
            } else {
                m.buffer[out++] = genNormals[Std.int(vidx/3)].x;
                m.buffer[out++] = genNormals[Std.int(vidx/3)].y;
                m.buffer[out++] = genNormals[Std.int(vidx/3)].z;
            }

            m.buffer[out++] = texAcc.float(vidx, 0);
            m.buffer[out++] = texAcc.float(vidx, 1);

            m.tangents[i<<2] = 1;
            m.indexes[i] = i;
        }

        m.compute();

        var arr: Array<Float> = [];
        for (i in 0 ... indices.length*4) {
            arr[i] = m.tangents[i];
        }
        return arr;
    }
    #end

    #if (sys || nodejs)
    private inline function generateTangentsSystem(
        posAcc: AccessorUtil,
        norAcc: AccessorUtil,
        texAcc: AccessorUtil,
        indices: Array<Int>,
        genNormals: Array<h3d.Vector>
    ): Array<Float> {
        //
        // find location for temporary files
        var tmp = Sys.getEnv("TMPDIR");
        if  (tmp == null) tmp = Sys.getEnv("TMP");
        if  (tmp == null) tmp = Sys.getEnv("TEMP");
        if  (tmp == null) tmp = ".";

        var now = Date.now().getTime();
        var nonce = Std.random(0x1000000);
        var filename = haxe.io.Path.join([
            tmp,
            "mikktspace_data" + now + "_" + nonce + ".bin",
        ]);

        // create mikktspace input data
        var outfile = filename + ".out";
        var dataBuffer = new haxe.io.BytesBuffer();

        dataBuffer.addInt32(indices.length);
        dataBuffer.addInt32(8); // ?
        dataBuffer.addInt32(0); // ?
        dataBuffer.addInt32(3); // ?
        dataBuffer.addInt32(6); // ?

        for (i in 0 ... indices.length) {
            var vidx = indices[i];
            dataBuffer.addFloat(posAcc.float(vidx, 0));
            dataBuffer.addFloat(posAcc.float(vidx, 1));
            dataBuffer.addFloat(posAcc.float(vidx, 2));

            if (norAcc != null) {
                dataBuffer.addFloat(norAcc.float(vidx, 0));
                dataBuffer.addFloat(norAcc.float(vidx, 1));
                dataBuffer.addFloat(norAcc.float(vidx, 2));
            } else {
                dataBuffer.addFloat(genNormals[Std.int(vidx/3)].x);
                dataBuffer.addFloat(genNormals[Std.int(vidx/3)].y);
                dataBuffer.addFloat(genNormals[Std.int(vidx/3)].z);
            }

            dataBuffer.addFloat(texAcc.float(vidx, 0));
            dataBuffer.addFloat(texAcc.float(vidx, 1));
        }

        dataBuffer.addInt32(indices.length);
        for (i in 0 ... indices.length) {
            dataBuffer.addInt32(i);
        }

        // save
        sys.io.File.saveBytes(filename, dataBuffer.getBytes());

        // run mikktspace
        var ret = try Sys.command("mikktspace", [filename, outfile])
                  catch (e: Dynamic) -1;
        if (ret != 0) {
            sys.FileSystem.deleteFile(filename);
            throw "Failed to call 'mikktspace' executable required to generate tangent data. Please ensure it's in your PATH";
        }

        var arr = [];
        var bytes = sys.io.File.getBytes(outfile);
        for (i in 0 ... indices.length*4) {
            arr[i] = bytes.getFloat(i << 2);
        }

        // cleanup
        sys.FileSystem.deleteFile(filename);
        sys.FileSystem.deleteFile(outfile);
        return arr;
    }
    #end

    private inline function nodeToPos(node: GltfNode): hxd.fmt.hmd.Data.Position {
        var ret = new hxd.fmt.hmd.Data.Position();

        if (node.translation != null) {
            ret.x = node.translation[0];
            ret.y = node.translation[1];
            ret.z = node.translation[2];
        } else {
            ret.x = 0.0;
            ret.y = 0.0;
            ret.z = 0.0;
        }
        if (node.rotation != null) {
            var posW = node.rotation[3] > 0.0 ? 1.0 : -1.0;
            ret.qx = node.rotation[0] * posW;
            ret.qy = node.rotation[1] * posW;
            ret.qz = node.rotation[2] * posW;
        } else {
            ret.qx = 0.0;
            ret.qy = 0.0;
            ret.qz = 0.0;
        }
        if (node.scale != null) {
            ret.sx = node.scale[0];
            ret.sy = node.scale[1];
            ret.sz = node.scale[2];
        } else {
            ret.sx = 1.0;
            ret.sy = 1.0;
            ret.sz = 1.0;
        }

        return ret;
    }

    private inline function makePosition(m: h3d.Matrix) {
        var p = new hxd.fmt.hmd.Data.Position();
        var s = m.getScale();
        var q = new h3d.Quat();

        q.initRotateMatrix(m);
        q.normalize();
        if (q.w < 0) q.negate();

        p.sx = this.round(s.x);
        p.sy = this.round(s.y);
        p.sz = this.round(s.z);
        p.qx = this.round(q.x);
        p.qy = this.round(q.y);
        p.qz = this.round(q.z);
        p.x = this.round(m._41);
        p.y = this.round(m._42);
        p.z = this.round(m._43);
        return p;
    }

    public inline function round(v:Float) {
        if (v != v) throw "NaN found";
        return highPrecision ? v : std.Math.fround(v * 131072) / 131072;
    }

    private function buildSkin(
        nodeParents: Map<Int, Int>,
        gltfSkin: GltfSkin,
        name: String
    ): hxd.fmt.hmd.Data.Skin {
        var hmdSkin = new hxd.fmt.hmd.Data.Skin();
        hmdSkin.name = (
            gltfSkin.skeleton == null
            ? name
            : this.gltf.nodes[gltfSkin.skeleton].name
        ) + "_skin";
        hmdSkin.props = [FourBonesByVertex];
        hmdSkin.split = null;
        hmdSkin.joints = [];

        var acc = this.getAccessor(gltfSkin.inverseBindMatrices);

        for (i in 0 ... gltfSkin.joints.length) {
            var jInd = gltfSkin.joints[i];
            var jointNode = this.gltf.nodes[jInd];

            var hmdJoint = new hxd.fmt.hmd.Data.SkinJoint();
            hmdJoint.name = jointNode.name;
            hmdJoint.props = null;
            hmdJoint.position = this.nodeToPos(jointNode);
            hmdJoint.parent = gltfSkin.joints.indexOf(nodeParents[jInd]);
            hmdJoint.bind = i;

            var invBind = acc.matrix(i);
            hmdJoint.transpos = Util.posFromMatrix(invBind);

            // Copied from the FBX loader... Oh no......
            if (
                hmdJoint.transpos.sx != 1 ||
                hmdJoint.transpos.sy != 1 ||
                hmdJoint.transpos.sz != 1
            ) {
                // FIX: the scale is not correctly taken into account,
                // this formula will extract it and fix things
                var tmp = Util.posFromMatrix(invBind).toMatrix();
                tmp.transpose();
                var s = tmp.getScale();
                tmp.prependScale(1 / s.x, 1 / s.y, 1 / s.z);
                tmp.transpose();
                hmdJoint.transpos = this.makePosition(tmp);
                hmdJoint.transpos.sx = this.round(s.x);
                hmdJoint.transpos.sy = this.round(s.y);
                hmdJoint.transpos.sz = this.round(s.z);
            }

            hmdSkin.joints.push(hmdJoint);
        }

        return hmdSkin;
    }

    private inline function getAccessor(index: Int): AccessorUtil {
        if (index >= 0) {
            return new AccessorUtil(
                this.gltf,
                this.bytes,
                index,
                this.directory
            );
        }
        return null;
    }

    // Find the appropriate interval and weights from a time input curve
    private function interpAnimSample(
        inAcc: AccessorUtil,
        time: Float
    ): Dynamic { // TODO type
        // Find the nearest input values
        var lastVal =  inAcc.float(0, 0);
        if (time <= lastVal) {
            return { ind0: 0, weight: 1.0, ind1:-1};
        }
        // Iterate until we reach the appropriate interval
        // TODO: something much less inefficient
        var nextVal = 0.0;
        var nextInd = 1;
        while(nextInd < inAcc.count) {
            nextVal = inAcc.float(nextInd, 0);
            if (nextVal > time) {
                break;
            }
            if (nextVal < lastVal) {
                throw "nextVal decremented";
            }
            lastVal = nextVal;
            nextInd++;
        }
        var lastInd = nextInd-1;

        if (nextInd == inAcc.count) {
            return { ind0: lastInd, weight: 1.0, ind1:-1};
        }

        if (nextVal < lastVal) throw "nextVal decremented";
        if (lastVal > time) throw "lastVal too large";
        if (time > nextVal) throw "nextVal too small";
        if (nextVal == lastVal) {
            //Divide by zero guard
            return { ind0: lastInd, weight: 1.0, ind1:-1};
        }

        // calc weight
        var w = (nextVal-time)/(nextVal-lastVal);

        return { ind0: lastInd, weight: w, ind1:nextInd};
    }

    private inline function getPrimAccessor(
        prim: GltfMeshPrimitive,
        name: String
    ): AccessorUtil {
        var acc = prim.attributes.get(name);
        if (acc != null) {
            return this.getAccessor(acc);
        }
        return null;
    }

}
