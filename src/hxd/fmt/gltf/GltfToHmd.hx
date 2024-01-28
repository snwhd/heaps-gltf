package hxd.fmt.gltf;

import hxd.fmt.gltf.GltfData;


typedef AccessorUtil = Dynamic; // TODO


typedef NodeAnimationInfo = {
    var target: Int;
    var rotation: Array<Float>;
    var scale: Array<Float>;
    var translation: Array<Float>;
    var weights: Array<Float>;
    var hmdObject: hxd.fmt.hmd.Data.AnimationObject;
};


class GltfToHmd {

    // TODO: remove me, just for testing
    public static function main() {
        var path = Sys.args()[0];
        var content = sys.io.File.getContent(path);
        var convert = new GltfToHmd(
            haxe.io.Path.withoutDirectory(path),
            haxe.io.Path.directory(path),
            content,
            null // TODO: load binary chunk
        );
    }

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

    public function toHMD(): hxd.fmt.hmd.Data.Data {

        var out = new haxe.io.BytesOutput();

        //
        // load geometries
        //

        // var primBounds = [];
        // var dataPositions = [];
        var hmdGeometries: Array<hxd.fmt.hmd.Data.Geometry> = [];
        var geometryMaterials: Array<Array<Int>> = [];
        var meshToGeometry: Array<Array<Int>> = [];

        for (meshIndex => mesh in this.gltf.meshes.keyValueIterator()) {

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

                if (prim.mode != null && prim.mode != TRIANGLES) {
                    throw "TODO: non-triangle prims";
                }
                // var mode = if (prim.mode != null)
                //     ? prim.mode
                //     : TRIANGLES;

                //
                // load accessors
                //

                // TODO: verify accessor types
                var posAcc = this.getPrimAccessor(prim, "POSITION");
                var norAcc = this.getPrimAccessor(prim, "NORMAL");
                var texAcc = this.getPrimAccessor(prim, "TEXCOORD_0");
                var tanAcc = this.getPrimAccessor(prim, "TANGENT");
                var indAcc = this.getAccessor(
                    prim.indices != null ? prim.indices : -1
                );
                var jointAcc = this.getPrimAccessor(prim, "JOINTS_0");
                var weightAcc = this.getPrimAccessor(prim, "WEIGHTS_0");

                if (norAcc == null && indAcc != null) {
                    throw "generating normals on indexed models is not supported";
                }
                // TODO: check index?
                // if (jointAcc != weightAcc) {
                //     throw "joints/weights mismatch";
                // }

                //
                // generate normals & tangents
                //

                var indices: Array<Int> = [];
                if (indAcc != null) {
                    for (i in 0 ... indAcc.count) {
                        indices.push(indAcc.index(this.bytes, i));
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
                    var x = posAcc.float(this.bytes, i, 0);
                    var y = posAcc.float(this.bytes, i, 1);
                    var z = posAcc.float(this.bytes, i, 2);
                    out.writeFloat(x);
                    out.writeFloat(y);
                    out.writeFloat(z);
                    bounds.addPos(x, y, z);

                    if (norAcc != null) {
                        out.writeFloat(norAcc.float(this.bytes, i, 0));
                        out.writeFloat(norAcc.float(this.bytes, i, 1));
                        out.writeFloat(norAcc.float(this.bytes, i, 2));
                    } else {
                        var norm = generatedNormals[Std.int(i/3)];
                        out.writeFloat(norm.x);
                        out.writeFloat(norm.y);
                        out.writeFloat(norm.z);
                    }

                    if (tanAcc != null) {
                        out.writeFloat(norAcc.float(this.bytes, i, 0));
                        out.writeFloat(norAcc.float(this.bytes, i, 1));
                        out.writeFloat(norAcc.float(this.bytes, i, 2));
                    } else {
                        var index = i * 4;
                        out.writeFloat(generatedTangents[index++]);
                        out.writeFloat(generatedTangents[index++]);
                        out.writeFloat(generatedTangents[index]);
                    }

                    if (texAcc != null) {
                        out.writeFloat(texAcc.getFloat(this.bytes, i, 0));
                        out.writeFloat(texAcc.getFloat(this.bytes, i, 1));
                    } else {
                        out.writeFloat(0.5);
                        out.writeFloat(0.5);
                    }

                    if (jointAcc != null) {
                        for (jIndex in 0 ... 4) {
                            var joint = jointAcc.int(this.bytes, i, jIndex);
                            if (joint < 0) throw "negative joint index";
                            out.writeByte(joint);
                        }
                    }

                    if (weightAcc != null) {
                        for (wIndex in 0 ... 4) {
                            var weight = weightAcc.float(this.bytes, i, wIndex);
                            if (Math.isNaN(weight)) throw "weight is NaN";
                            out.writeFloat(weight);
                        }
                    }
                }


                //
                // create geometry
                //

                var geometry = new hxd.fmt.hmd.Data.Geometry();
                var mats = [];
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
                    format.push(new hxd.fmt.hmd.Data.GeometryFormat("weights", DVec4));
                }

                geometry.vertexFormat = hxd.BufferFormat.make(format);
                geometry.vertexPosition = primDataStart;
                geometry.bounds = bounds;

                // TODO: ?

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


        //
        // load materials
        //

        var hmdMaterials: Array<hxd.fmt.hmd.Data.Material> = [];
        // var inlineImages = []; // TODO: remove?
        // var materials = [];

        for (materialIndex => material in this.gltf.materials.keyValueIterator()) {
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

                var texture = this.gltf.textures[bcTexture.index];
                if (texture.source == null) throw "TODO";
                var image = this.gltf.images[texture.source];

                if (image.uri != null) {
                    if (StringTools.startsWith(image.uri, "http")) throw "TODO";
                    hmdMaterial.diffuseTexture = haxe.io.Path.join([
                        this.directory, // TODO: doesn't exist
                        image.uri
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
                    var length = this.gltf.bufferViews[image.bufferView].byteLength;
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
                    //     mat: materialIndex,
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

            hmdMaterial.blendMode = None;
            hmdMaterials.push(hmdMaterial);
        }


        //
        // load models
        //

        var identityPos = new hxd.fmt.hmd.Data.Position();
        Util.initializePosition(identityPos);

        var root = new hxd.fmt.hmd.Data.Model();
        root.name = "TODO: mode name";
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

        function checkJoints(i) {
            if (!jointNodes.exists(i)) throw "joint child is not a joint";

            var node = this.gltf.nodes[i];
            if (node.mesh != null) throw "joints with meshes not supported";

            for (child in node.children) {
                checkJoints(child);
            }
        }

        // validate joints and preallocate node indices
        var modelCount = hmdModels.length;
        var nodeParents: Map<Int, Int> = [];
        var outputIndices: Map<Int, Int> = [];
        for (nodeIndex => node in this.gltf.nodes.keyValueIterator()) {
            if (jointNodes.exists(nodeIndex)) {
                checkJoints(nodeIndex);
            } else {
                outputIndices[nodeIndex] = modelCount++;
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
            if (parent == null) {
                parent = -1;
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
                        this.gltf.skins[node.skin],
                        node.name
                    );
                }

                var geometries = meshToGeometry[node.mesh];
                if (geometries.length == 1) {
                    // we can put a single geometry into the node
                    hmdModel.geometry = geometries[0];
                    hmdModel.materials = geometryMaterials[hmdModel.geometry];
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

        var hmdAnimations: Array<hxd.fmt.hmd.Data.Animation> = [];
        if (this.gltf.animations != null) for (anim in this.gltf.animations) {

            //
            // constant data
            //

            var hmdAnimation = new hxd.fmt.hmd.Data.Animation();
            hmdAnimation.name = anim.name;
            hmdAnimation.props = null;
            hmdAnimation.sampling = ANIMATION_SAMPLE_RATE;
            hmdAnimation.speed = 1.0;
            hmdAnimation.loop = false;

            //
            // parse data from gltf channels
            //

            function newNodeAnimationInfo(target: Int) {
                return {
                    target: target, // TODO: remove target?
                    rotation: null,
                    scale: null,
                    translation: null,
                    weights: null,
                    hmdObject: new hxd.fmt.hmd.Data.AnimationObject(),
                };
            }

            // mape from node index to animation values
            var nodeAnimationMap : Map<Int, NodeAnimationInfo> = [];

            // used to calculate length & number of frames
            var start = Math.POSITIVE_INFINITY;
            var end = Math.NEGATIVE_INFINITY;

            for (channel in anim.channels) {

                // TODO: warn on missing target?
                if (channel.target.node == null) continue;

                // for animation length
                var sampler = anim.samplers[channel.sampler];
                var accessor = this.getAccessor(sampler.input);
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
                    hmdAnimation.objects.push(info.hmdObject);
                    info.hmdObject.name = this.gltf.nodes[channel.target.node].name;
                }

                switch (channel.target.path) {
                    case "translation":
                        if (info.translation != null) {
                            throw "multiple translations";
                        }
                        info.translation = this.sampleCurve(
                            channel.sampler,
                            3,
                            false
                        );
                        info.hmdObject.flags.set(HasPosition);
                    case "rotation":
                        if (info.rotation != null) throw "multiple rotations";
                        info.rotation = this.sampleCurve(
                            channel.sampler,
                            4,
                            true
                        );
                        info.hmdObject.flags.set(HasRotation);
                    case "scale":
                        if (info.scale != null) throw "multiple scales";
                        info.scale = this.sampleCurve(
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

            // calculate number of frames
            var length = end - start;
            hmdAnimation.frames = Std.int((end - start) * ANIMATION_SAMPLE_RATE);

            // load animation flags
            hmdAnimation.objects = [];

            // load animation data
            var infos = [ for (v in nodeAnimationMap) v ];

            //
            // write frame data
            //

            for (frameIndex in 0 ... hmdAnimation.frames) {
                for (info in infos) {

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


        //
        // build hmd data
        //

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
        data.models = hmdModels;
        data.materials = hmdMaterials;
        data.geometries = hmdGeometries;
        data.animations = hmdAnimations;
        data.dataPosition = 0;
        data.data = out.getBytes();
        return data;
    }

    private function readWholeBuffer(bufferView: Int): haxe.io.Bytes {
        throw "TODO";
    }

    private function sampleCurve(
        sampleId: Int,
        numComps: Int,
        isQuat: Bool
    ): Array<Float> {
        throw "TODO";
    }

    private function generateNormals(posAcc: AccessorUtil): Array<h3d.Vector> {
        throw "TODO";
    }

    private function generateTangents(
        posAcc: AccessorUtil,
        norAcc: AccessorUtil,
        texAcc: AccessorUtil,
        indices: Array<Int>
    ): Array<Float> {
        throw "TODO";
    }

    private function nodeToPos(node: GltfNode): hxd.fmt.hmd.Data.Position {
        throw "TODO";
    }

    private function buildSkin(
        gltfSkin: GltfSkin,
        name: String
    ): hxd.fmt.hmd.Data.Skin {
        throw "TODO";
    }

    private function getAccessor(index: Int): AccessorUtil {
        if (index >= 0) {
            return new AccessorUtil(
                index,
                this.gltf.accessors[index]
            );
        }
        return null;
    }

    private function getPrimAccessor(
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
