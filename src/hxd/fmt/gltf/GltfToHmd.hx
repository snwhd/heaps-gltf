package hxd.fmt.gltf;

import hxd.fmt.gltf.GltfParser;


class GltfToHmd {

    private static inline var ANIMATION_SAMPLE_RATE = 60.0;

    private var parser: GltfParser;

    public function new(parser: GltfParser) {
        this.parser = parser;
    }

    public function toHMD(): hxd.fmt.hmd.Data {

        var gltf = this.parser.gltf;
        var out = new haxe.io.BytesOutput();

        //
        // load models
        //

        var models: Array<hxd.fmt.hmd.Data.Model> = [];

        //
        // load materials
        //

        var materials: Array<hxd.fmt.hmd.Data.Material> = [];

        //
        // load geometries
        //

        var geometries: Array<hxd.fmt.hmd.Data.Geometry> = [];

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
