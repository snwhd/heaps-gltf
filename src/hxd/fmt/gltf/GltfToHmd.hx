package hxd.fmt.gltf;

import hxd.fmt.gltf.GltfData;


class GltfToHmd {

    // TODO: remove me, just for testing
    // public static function main() {
    //     var path = Sys.args()[0];
    //     var content = sys.io.File.getContent(path);
    //     var convert = new GltfToHmd(
    //         haxe.io.Path.withoutDirectory(path),
    //         haxe.io.Path.directory(path),
    //         content,
    //         null // TODO: load binary chunk
    //     );
    // }

    private static inline var ANIMATION_SAMPLE_RATE = 60.0;

    public var filename: String;
    public var directory: String;
    public var bytes: haxe.io.Bytes;
    public var gltf: GltfData;

    public function new(
        filename: String,
        directory: String,
        textChunk: String,
        ?bytes: haxe.io.Bytes
    ): Void {
        this.filename = filename;
        this.directory = directory;
        this.bytes = bytes;
        this.gltf = haxe.Json.parse(textChunk);
    }

    public function toHMD(): hxd.fmt.hmd.Data {

        var gltf = this.parser.gltf;
        var bytes = this.parser.bytes;
        var out = new haxe.io.BytesOutput();


        //
        // load geometries
        //

        // var primBounds = [];
        // var dataPositions = [];
        var hmdGeometries: Array<hxd.fmt.hmd.Data.Geometry> = [];
        var geometryMaterials: Array<Array<Int>> = [];
        var meshToGeometry: Array<Array<Int>> = [];

        for (meshIndex => mesh in gltf.meshes.keyValueIterator()) {

            var meshGeoList = [];
            meshToGeometry.push(meshGeoList);

            for (prim in mesh.primitives) {

                // TODO: deduplicate primitives?

                var primDataStart = out.length;
                // var dataPositions.push(out.length);
                var bounds = new h3d.col.Bounds();
                bounds.empty();
                // primBounds.push(bounds);

                var materialIndex = prim.material;

                if (mode != null && mode != TRIANGLES) {
                    throw "TODO: non-triangle prims";
                }
                // var mode = if (prim.mode != null)
                //     ? prim.mode
                //     : TRIANGLES;

                //
                // load accessors
                //

                function getAccessor(index: Int) {
                    if (index < 0) return null;
                    return new AccessorUtil(index, gltf.accessors[index]);
                }

                function getPrimAccessor(name: String) {
                    var acc = prim.attributes.get(name);
                    return acc != null ? acc : -1;
                }

                // TODO: verify accessor types
                var posacc = getPrimAccessor("POSITION");
                var noracc = getPrimAccessor("NORMAL");
                var texacc = getPrimAccessor("TEXCOORD_0");
                var tanacc = getPrimAccessor("TANGENT");
                var indacc = getAccessor(prim.indices != null ? prim  = -1);
                var jointAcc = getPrimAccessor("JOINTS_0");
                var weightAcc = getPrimAccessor("WEIGHTS_0");

                if (norAcc == null && indAcc != null) {
                    throw "generating normals on indexed models is not supported";
                }
                // TODO: check index?
                // if (jointsAcc != weightsAcc) {
                //     throw "joints/weights mismatch";
                // }

                //
                // generate normals & tangents
                //

                var indices: Array<Int> = [];
                if (indAcc != null) {
                    for (i in 0 ... indAcc.count) {
                        indices.push(indAcc.index(bytes, i));
                    }
                } else {
                    for (i in 0 ... posAcc.count) {
                        indices.push(i);
                    }
                }

                var generatedNormals = null;
                if (norAcc == null) {
                    // TODO
                    generatedNormals = this.generateNormals(posAcc);
                }

                var generatedTangents = null;
                if (tanAcc == null) {
                    generatedTangents = this.generateTangents(
                        posAcc,
                        norAcc,
                        texAcc,
                        indices
                    );
                } else {
                    // TODO: option to force generate tangents
                }

                //
                // write data
                //

                for (i in 0 ... posAcc.count) {
                    var x = posAcc.float(bytes, i, 0)
                    var y = posAcc.float(bytes, i, 1)
                    var z = posAcc.float(bytes, i, 2)
                    out.writeFloat(x);
                    out.writeFloat(y);
                    out.writeFloat(z);
                    bounds.addPos(x, y, z);

                    if (norAcc != null) {
                        out.writeFloat(norAcc.float(bytes, i, 0));
                        out.writeFloat(norAcc.float(bytes, i, 1));
                        out.writeFloat(norAcc.float(bytes, i, 2));
                    } else {
                        var norm = generatedNormals[Std.int(i/3)];
                        out.writeFloat(norm.x);
                        out.writeFloat(norm.y);
                        out.writeFloat(norm.z);
                    }

                    if (tanAcc != null) {
                        out.writeFloat(norAcc.float(bytes, i, 0));
                        out.writeFloat(norAcc.float(bytes, i, 1));
                        out.writeFloat(norAcc.float(bytes, i, 2));
                    } else {
                        var index = i * 4;
                        out.writeFloat(generatedTangents[index++]);
                        out.writeFloat(generatedTangents[index++]);
                        out.writeFloat(generatedTangents[index]);
                    }

                    if (texAcc != null) {
                        out.writeFloat(texAcc.getFloat(bytes, i, 0));
                        out.writeFloat(texAcc.getFloat(bytes, i, 1));
                    } else {
                        out.writeFloat(0.5);
                        out.writeFloat(0.5);
                    }

                    if (jointsAcc != null) {
                        for (jIndex in 0 ... 4) {
                            var joint = jointsAcc.int(bytes, i, jIndex);
                            if (joint < 0) throw "negative joint index";
                            out.writeByte(joint);
                        }
                    }

                    if (weightsAcc != null) {
                        for (wIndex in 0 ... 4) {
                            var weight = wightsAcc.float(bytes, i, wIndex);
                            if (Math.isNan(weight)) throw "weight is NaN";
                            out.write(weight);
                        }
                    }
                }


                //
                // create geometry
                //

                var geometry = new hxd.fmt.hmd.Geometry();
                var mats = [];
                meshGeoList.push(hmdGeometries.length);
                geometryMaterials.push(mats);
                hmdGeometries.push(geometry);

                geometry.props = null;
                geometry.vertexCount = posAcc.count;

                // build vertex format
                var format = [
                    new GeometryFormat("position", DVec3),
                    new GeometryFormat("normal", DVec3),
                    new GeometryFormat("tangent", DVec3),
                    new GeometryFormat("uv", DVec2),
                ];
                if (jointsAcc != null) {
                    format.push(new GeometryFormat("indexes", DBytes4));
                    format.push(new GeometryFormat("weights", DVec4));
                }

                geometry.vertexFormat = hxd.BufferFormat.make(format);
                geometry.vertexPosition = primDataStart;
                geometry.bounds = bounds;

                // TODO: ?

                var is32 = geometry.vertexCount > 0x10000;
                geometry.indexPosition = out.length;
                geometry.indexCounts = [indices.length];
                if (i32) {
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


        //
        // load materials
        //

        var hmdMaterials: Array<hxd.fmt.hmd.Data.Material> = [];
        // var inlineImages = []; // TODO: remove?
        // var materials = [];

        for (materialIndex => material in gltf.materials.keyValueIterator()) {
            var hmdMaterial = new hxd.fmt.hmd.Material();
            hmdMaterial.name = material.name;

            if (pbr.baseColorTexture != null) {
                var bcTexture = pbr.baseColorTexture;
                var coord = bcTexture.texCoord == null
                    ? 0
                    : bcTexture.texCoord;
                if (coord != 0) {
                    throw "TODO: nonzero texcoord";
                }

                var texture = gltf.textures[bcTexture.index];
                if (texture.source == null) throw "TODO";
                var image = gltf.images[texture.source];

                if (image.uri != null) {
                    if (StringTools.startsWith(image.uri, "http") throw "TODO";
                    hmdMaterial.diffuseTexture = haxe.io.Path.join([
                        this.directory, // TODO: doesn't exist
                        image.uri
                    ])
                } else if (image.bufferView != null) {
                    var ext = switch (image.mineType) {
                        case "image/png": "PNG";
                        case "image/jpeg": "JPG";
                        case s: throw 'unknown image format: $s';
                    }

                    // TODO: bundle these and move to the end?
                    // append inline images to binary data
                    var start = outBytes.length;
                    var length = image.bufferView.byteLength;
                    hmdMaterial.diffuseTexture = '$ext@$start--$length';
                    outBytes.writeBytes(this.readWholeBuffer(image.bufferView));

                    // inlineImages.push({
                    //     buf: image.bufferView.buffer,
                    //     pos: image.bufferView.byteOffset,
                    //     len: image.bufferView.byteLength,
                    //     mat: materialIndex,
                    //     ext: ext,
                    // });
                } else {
                    throw "material imagem ust have buffer or uri";
                }
            #if !heaps_gltf_disable_material_patch
            } else if (
                material.color != null &&
                material.pbrMetallicRoughness != null &&
                material.pbrMetallicRoughness.baseColorFactor != null
            ) {
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

            hmdMaterial.blendMode = None;
            hmdMaterials.push(hmdMaterial);
        }


        //
        // load models
        //

        var root = new hxd.fmt.hmd.Data.Model();
        root.name = "TODO: mode name";
        root.props = null;
        root.parent = -1;
        root.follow = null;
        root.position = new hxd.fmt.hmd.Position();
        Util.initializePosition(root.position);
        root.skin = null;
        root.geometry = -1;
        root.materials = null;

        var hmdModels: Array<hxd.fmt.hmd.Data.Model> = [];
        hmdModels.push(root);

        // identify joints
        var jointNodes: Map<Int, Bool> = [];
        if (gltf.skins != null) for (skin in gltf.skins) {
            for (jointIndex in skin.joints) {
                jointNodes[jointIndex] = true;
            }
        }

        function checkJoints(i) {
            if (!jointNodes.exists(i)) throw "joint child is not a joint";

            var node = gltf.nodes[i];
            if (node.mesh != null) throw "joints with meshes not supported";

            for (child in node.children) {
                checkJoints(child);
            }
        }

        // validate joints and preallocate node indices
        var modelCount = hmdModels.length;
        var outputIndices: Map<Int, Int> = [];
        for (nodeIndex => node in gltf.nodes.keyValueIterator()) {
            if (jointNodes.exists(nodeIndex)) {
                checkJoints(nodeIndex);
            } else {
                outputIndices[nodeIndex] = modelCount++;
            }
        }
        hmdModels.resize(modelCount);

        for (nodeIndex => node in gltf.nodes.keyValueIterator()) {
            if (jointNodes.exists(nodeIndex)) continue;

            var hmdModel = new hxd.fmt.hmd.Model();
            hmdModel.name = node.name;
            hmdModel.props = null;
            hmdModel.parent = node.parent == null ? 0 : outputIndices[node.parent];
            hmdModel.follow = null;
            hmdModel.position = this.nodeToPos(node);
            hmdModel.skin = null;

            hmdModel.geometry = -1;
            hmdModel.materials = null;
            if (node.mesh != null) {
                if (node.skin != null) {
                    model.skin = this.buildSkin(
                        gltf.skins[node.skin],
                        node.name
                    );
                }

                var geometries = meshToGeometry[node.mesh];
                if (geometries.length == 1) {
                    // we can put a single geometry into the node
                    model.geometry = geometries[0];
                    model.materials = geometryMaterials[model.geometry];
                } else for (geometryIndex in geometries) {
                    // model per primitive
                    var primModel = new hxd.fmt.hmd.Model();
                    primModel.name = gltf.meshes[node.mesh].name;
                    primModel.props = null;
                    primModel.parent = outputIndices[nodeIndex];
                    primModel.position = identPos; // TODO
                    primModel.follow = null;
                    primModel.skin = null;
                    primModel.geometry = geometryIndex;
                    primModel.materials = geometryMaterials[geometryIndex];
                    // TODO: modelCount++ ?
                    hmdModels.push(primModel);
                }
            }

            hmdModels[outputIndices[nodeIndex]] = hmdModel;
        }


        //
        // load animations
        //

        var hmdAnimations: Array<hxd.fmt.hmd.Animation> = [];
        if (gltf.animations != null) for (animation in gltf.animations) {

            //
            // constant data
            //

            var hmdAnimation = new hxd.fmt.hmd.Data.Animation();
            hmdAnimation.name = animation.name;
            hmdAnimation.props = null;
            hmdAnimation.sampling = ANIMATION_SAMPLE_RATE;
            hmdAnimation.speed = 1.0;
            hmdAnimation.loop = false;

            //
            // parse data from gltf channels
            //

            typedef NodeAnimationInfo = {
                var target: Int;
                var rotation: GltfAnimationTarget;
                var scale: GltfAnimationTarget;
                var translation: GltfAnimationTarget;
                var weights: GltfAnimationTarget;
                var hmdObject: hxd.fmt.hmd.Data.AnimationObject;
            };

            function newNodeAnimationInfo(target: Int) {
                return {
                    target: target, // TODO: remove target?
                    rotation: null,
                    scale: null,
                    translation: null,
                    weights: null,
                    hmdObject = new hxd.fmt.hmd.Data.AnimationObject(),
                };
            }

            // mape from node index to animation values
            var nodeAnimationMap : Map<Int, NodeAnimationInfo> = [];

            // used to calculate length & number of frames
            var start = Math.POSITIVE_INFINITY;
            var end = Math.NEGATIVE_INFINITY;

            for (channel in animation.channels) {

                // TODO: warn on missing target?
                if (channel.target.node == null) continue;

                // for animation length
                var sampler = gltf.getSampler(channel.sampler);
                var accessor = gltf.getAccessor(channel.input);
                if (accessor.max != null) {
                    end = Math.max(end, accessor.max);
                }
                if (accessor.min != null) {
                    start = Math.min(start, accessor.min);
                }

                //
                // extract animation curves for each node
                //

                var nodeIndex = channel.target.node;
                // TODO: mark node as animated (?)
                var info = nodeAnimationMap.get(nodeIndex);
                if (info == null) {
                    // create a new info/curve
                    info = newNodeAnimationInfo(channel.target.node);
                    nodeAnimationMap[nodeIndex] = info;

                    // save to output object
                    hmdAnimation.objects.push(info.hmdObjects);
                    info.hmdObject.name = gltf.nodes[target.node].name;
                }

                switch (channel.target.path) {
                    case "translation":
                        if (info.translation != null) throw "multiple translations";
                        info.translation = sampleCurve(channel.sampler, 3, false);
                        info.hmdObject.flags.set(HasPosition);
                    case "rotation":
                        if (info.rotation != null) throw "multiple rotations";
                        info.rotation = sampleCurve(channel.sampler, 4, true);
                        hmdAnimationObject.flags.set(HasRotation);
                    case "scale":
                        if (info.scale != null) throw "multiple scales";
                        info.scale = sampleCurve(channel.sampler, 3, false);
                        hmdAnimationObject.flags.set(HasScale);
                    case "weights":
                        if (info.weights) throw "multiple weights";
                        throw "TODO: weights";
                        // info.weights = sampleCurve(channel.sampler, 3, false);
                        // hmdAnimationObject.flags.set(HasWeights);
                }
            }

            // calculate number of frames
            var length = end - start;
            hmdAnimation.frames = Std.int((end - start) * ANIMATION_SAMPLE_RATE);

            // load animation flags
            hmdAnimation.objects = [];

            // load animation data
            var infos = [ for (v in nodeAnimationMap.values()) v ];

            //
            // write frame data
            //

            for (frameIndex in 0 ... frames) {
                for (info in infos) {

                    if (info.translation != null) {
                        var index = frameIndex * 3;
                        out.writeFloat(info.translation[index++]);
                        out.writeFloat(info.translation[index++]);
                        out.writeFloat(info.translation[index]);
                    }

                    if (info.rotation != null) {
                        var index = frameIndex * 4;
                        var quat = new Quat(
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


        //
        // build hmd data
        //

        var data = new hxd.fmt.hmd.Data();
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
        data.models = hmdModels;
        data.materials = hmdMaterials;
        data.geometries = hmdGeometries;
        data.animations = hmdAnimations;
        data.dataPosition = 0;
        data.data = out.getBytes();
        return data;
    }
}
