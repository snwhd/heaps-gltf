package hxd.fmt.gltf;


//
// Data Types
//


 enum abstract ComponentType(Int) {
    var BYTE   = 5120;
    var UBYTE  = 5121;
    var SHORT  = 5122;
    var USHORT = 5123;
    var UINT   = 5125;
    var FLOAT  = 5126;
}


 enum abstract AccessorType(String) {
    var SCALAR;
    var VEC2;
    var VEC3;
    var VEC4;
    var MAT2;
    var MAT3;
    var MAT4;
}


 enum abstract AttributeName(String) from String to String {
    var POSITION;
    var NORMAL;
    var TANGENT;
    var TEXCOORD_0;
    var TEXCOORD_1;
    var TEXCOORD_2;
    var TEXCOORD_3;
    var COLOR_0;
    var WEIGHTS_0;
    var JOINTS_0;
}


 enum abstract GltfMeshPrimitiveMode(Int) from Int to Int {
    var POINTS = 0;
    var LINE_STRIPS;
    var LINE_LOOPS;
    var LINES;
    var TRIANGLES; // default
    var TRIANGLE_STRIPS;
    var TRIANGLE_FANS;
}


 enum abstract SamplerMagnificationType(Int) from Int to Int {
    var NEAREST = 9728;
    var LINEAR  = 9729;
}


 enum abstract SamplerMinificationType(Int) from Int to Int {
    var NEAREST = 9728;
    var LINEAR  = 9729;
    var NEAREST_MIPMAP_NEAREST = 9984;
    var LINEAR_MIPMAP_NEAREST = 9985;
    var NEAREST_MIPMAP_LINEAR = 9986;
    var LINEAR_MIPMAP_LINEAR = 9987;
}


 enum abstract SamplerWrapType(Int) from Int to Int {
    var CLAMP_TO_EDGE = 33071;
    var MIRRORED_REPEAT = 33648;
    var REPEAT = 10497;
}

 enum abstract AlphaMode(String) from String to String {
    var OPAQUE;
    var MASK;
    var BLEND;
}


 enum abstract AnimationInterpolationType(String) from String to String {
    var LINEAR;
    var STEP;
    var CUBICSPLINE;
}


 enum abstract CameraType(String) from String to String {
    var perspective;
    var orthographic;
}


//
// Json Typing
//


 typedef GltfAsset = {
    // required fields
    var version: String;

    var copyright: String;
    var generator: String;
    var minVersion: String;
}


 typedef GltfBuffer = {
    // required fields
    var byteLength: Int;

    var uri: String;
    var name: String;
}


 var GLTF_BUFFER_VIEW_DEFAULT_BYTEOFFSET = 0;
 typedef GltfBufferView = {
    // required fields
    var buffer: Int;
    var byteLength: Int;

    var byteOffset: Int; // = GLTF_BUFFER_VIEW_DEFAULT_BYTEOFFSET

    // only used for vertex attribute data
    var byteStride: Int;

    // for vertex indices this is element array buffer
    // for attribute accessors this is array buffer
    var target: Int;

    var name: String;
}


 var GLTF_NODE_DEFAULT_MATRIX = [
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0,
];
 var GLTF_NODE_DEFAULT_ROTATION = [0.0, 0.0, 0.0, 1.0];
 var GLTF_NODE_DEFAULT_SCALE = [1.0, 1.0, 1.0];
 var GLTF_NODE_DEFAULT_TRANSLATION = [0.0, 0.0, 0.0];
 typedef GltfNode = {
    // no required fields

    // index<gltf.cameras>
    var camera: Int;

    // index<gltf.nodes>
    var children: Array<Int>;

    var name: String;

    // T * R * S
    var rotation: Array<Int>;      // = GLTF_NODE_DEFAULT_ROTATION;
    var scale: Array<Int>;         // = GLTF_NODE_DEFAULT_SCALE;
    var translation: Array<Float>; // = GLTF_NODE_DEFAULT_TRANSLATION;

    // index<gtlf.meshes>
    var mesh: Int;
    // index<gltf.skins>
    var skin: Int;

    // local space transform
    // not available if referenced by animations
    var matrix: Array<Float>;

    // TODO
    var weights: Array<Int>;
}


 typedef GltfScene = {
    // no required fields

    var name: String;
    var nodes: Array<Int>;
}


 typedef GltfSparseAccessorIndices = {
    // required fields
    var bufferView: Int;
    var componentType: ComponentType;

    var byteOffset: Int; // TODO = 0;
}


 typedef GltfSparseAccessorValues = {
    // required fields
    var bufferView: Int;

    var byteOffset: Int; // TODO = 0;
}


 typedef GltfSparseAccessor = {
    // required fields
    var count: Int;
    var indices: GltfSparseAccessorIndices;
    var values: GltfSparseAccessorValues;
}


 typedef GltfAccessor = {
    // required fields
    var componentType: ComponentType;
    var count: Int;
    var type: AccessorType;

    // index<gltf.bufferViews>
    var bufferView: Int;

    // starting point, then steps are defined by bufferView.byteStride for
    // vertex data, and tightly packed for other data types
    var byteOffset: Int; // TODO = 0;

    var normalized: Bool; // TODO = false;

    var max: Array<Float>;
    var min: Array<Float>;

    // must be defined if bufferView is not
    var sparse: GltfSparseAccessor;
    var name: String;
}


 typedef GltfMeshPrimitive = {
    // required fields
    // map<attribute, index<gltf.accessor>>
    var attributes: Map<AttributeName, Int>;

    var indices: Int;

    // index<gltf.materials>
    var material: Int;

    var mode: GltfMeshPrimitiveMode; // TODO = TRIANGLES;

    // morph targets
    var targets: Map<AttributeName, Int>;
}


 typedef GltfMesh = {
    // required fields
    var primitives: Array<GltfMeshPrimitive>;

    var weights: Array<Int>;
    var name: String;
}


 typedef GltfSkin = {
    // require fields
    // index<gltf.accessors>
    var joints: Array<Int>;

    // index<gltf.accessors>, must be float MAT4
    var inverseBindMatrices: Array<Int>;

    // index<gltf.nodes>
    var skeleton: Int;

    var name: String;
}


 typedef GltfTexture = {
    // no required fields

    var sampler: Int;
    var source: Int;
    var name: String;
}


 typedef GltfImage = {
    // no required fields

    // must contain either uri or bufferView
    var uri: String;

    // required if using bufferView
    var mimeType: String;

    // index<gltf.bufferViews>
    var bufferView: Int;

    var name: String;
}


 typedef GltfSampler = {
    // no required fields

    var magFilter: Null<SamplerMagnificationType>;
    var minFilter: Null<SamplerMinificationType>;
    var wrapS: SamplerWrapType; // TODO = REPEAT;
    var wrapT: SamplerWrapType; // TODO = REPEAT;
    var name: String;
}


 typedef GltfTextureInfo = {
    // required fields
    var index: Int;

    var texCoord: Int; // TODO = 0;
}


 var DEFAULT_PBR_COLOR_FACTOR = [1.0, 1.0, 1.0, 1.0];
 typedef GltfPbrMetallicRoughness = {
    // no rquired fields

    var baseColorFactor: Array<Float>; // TODO = DEFAULT_PBR_COLOR_FACTOR;
    var baseColorTexture: GltfTextureInfo;
    var metallicFactor: Float; // TODO = 1.0
    var roghnessFactor: Float; // TODO = 1.0
    var metallicRoughnessTexture: GltfTextureInfo;
}


 typedef GltfMaterialNormalTexture = {
    // required fields
    var index: Int;

    var texCoord: Int; // TODO = 0;
    var scale: Float;  // TODO = 1.0;
}


 typedef GltfMaterialOcclusionTexture = {
    // required fields
    var index: Int;

    var texCoord: Int;   // TODO = 0;
    var strength: Float; // TODO = 1.0;
}


 var DEFAULT_MATERIAL_EMISSIVE_FACTOR = [0.0, 0.0, 0.0];
 typedef GltfMaterial = {
    // no required fields

    var name: String;
    var pbrMetallicRoughness: GltfPbrMetallicRoughness;
    var normalTexture: GltfMaterialNormalTexture;
    var occlusionTexture: GltfMaterialOcclusionTexture;
    var emissiveTexture: GltfTextureInfo;
    var emissiveFactor: Array<Float>; // TODO = DEFAULT_MATERIAL_EMISSIVE_FACTOR;
    var alphaMode: AlphaMode; // TODO = OPAQUE;
    var alphaCutoff: Float; // TODO = 0.5;
    var doubleSided: Bool;  // TODO = false;
}


 typedef GltfAnimationChannelTarget = {
    // required fields
    var path: String;

    var node: Int;
}


 typedef GltfAnimationChannel = {
    // required fields
    var sampler: Int;
    var target: GltfAnimationChannelTarget;
}


 typedef GltfAnimationSampler = {
    // required fields
    var input: Int;
    var output: Int;

    var string: AnimationInterpolationType; // TODO = LINEAR
}


 typedef GltfAnimation = {
    // required fields
    var channels: GltfAnimationChannel;
    var samples: GltfAnimationSampler;

    var name: String;;
}


 typedef GltfCameraOrthographic = {
    // require fields
    var xmag: Float;  // > 0
    var ymag: Float;  // > 0
    var zfar: Float;  // > 0
    var znear: Float; // > 0
}


 typedef GltfCameraPerspective = {
    // require fields
    var yfov: Float; // < pi
    var znear: Float;

    var aspectRatio: Float;
    var zfar: Float;
}


 typedef GltfCamera = {
    // required fields
    var type: CameraType;

    var orthographic: GltfCameraOrthographic;
    var perspective: GltfCameraPerspective;
    var name: String;
}


 typedef GltfData = {
    // required fields
    var asset: GltfAsset;

    // TODO: var extensionsUsed: Array<String>;
    // TODO: var extensionsRequired: Array<String>;

    var buffers: Array<GltfBuffer>;
    var bufferViews: Array<GltfBufferView>;
    var accessors: Array<GltfAccessor>;

    var nodes: Array<GltfNode>;
    var scenes: Array<GltfScene>;
    var scene: Int;

    var meshes: Array<GltfMesh>;
    var skins: Array<GltfSkin>;

    var textures: Array<GltfTexture>;
    var images: Array<GltfImage>;
    var samplers: Array<GltfSampler>;
    var materials: Array<GltfMaterial>;

    var animations: Array<GltfAnimation>;

    var cameras: Array<GltfCamera>;
}


//
// Actual Parser
//


class GltfParser {

    // public static function main() {
    //     var path = Sys.args()[0];
    //     trace('checking $path');
    //     var content = sys.io.File.getContent(path);
    //     var data: GltfData = haxe.Json.parse(content);
    //     var n = data.meshes.length;
    //     trace('$n meshes');
    // }

    public var filename: String;
    public var directory: String;
    public var bytes: haxe.io.Bytes;
    public var gltf: GltfData;

    public function new(
        filename: String,
        directory: String,
        textChunk: String,
        ?data: haxe.io.Bytes
    ): Void {
        this.filename = filename;
        this.directory = directory;
        this.bytes = binChunk;
        this.gltf = Json.parse(textChunk);
        // TODO: default values?
    }

    // TODO: loadGltf
    // TODO: loadGlb

}
