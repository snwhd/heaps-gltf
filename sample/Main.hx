

class Main extends hxd.App {

    public static function main() {
        new Main();
    }

    private var object: h3d.scene.Object;
    private var animation: h3d.anim.Animation;

    override function init() {
        hxd.Res.initEmbed();
        var lights : h3d.scene.fwd.LightSystem = cast this.s3d.lightSystem;
        lights.ambientLight.set(1.0, 1.0, 1.0);
        this.s3d.camera.pos.set(0.0, -0.25, 0.0);
        this.s3d.camera.target.set(0, 0, 0);
        new h3d.scene.CameraController(5, this.s3d).loadFromCamera();

        var cache = new h3d.prim.ModelCache();

        var model = hxd.Res.loader.load("test1.gltf").toModel();
        this.object = cache.loadModel(model);
        this.animation = cache.loadAnimation(model, "EngineSpin.001");

        // this.object = cache.loadModel(hxd.Res.loader.load("Avocado.gltf").toModel());
        // this.object = cache.loadModel(hxd.Res.loader.load("bench/car/ToyCar.gltf").toModel());
        // this.object = cache.loadModel(hxd.Res.loader.load("Fox.glb").toModel());

        this.object.rotate(Math.PI/2, 0, 0);
        for (i in 0 ... this.object.numChildren) {
            var m = Std.downcast(this.object.getChildAt(i), h3d.scene.Mesh);
            if (m != null) {
                m.material.shadows = false;
            }
        }
        this.object.z = -0.035;
        this.s3d.addChild(this.object);
    }

    override function update(dt: Float) {
        if (hxd.Key.isPressed(hxd.Key.SPACE) && this.animation != null) {
            trace('playing: ${this.animation.name}');
            this.object.playAnimation(this.animation);
        } else if (hxd.Key.isDown(hxd.Key.D)) {
            this.object.rotate(0, 0, dt*Math.PI/4);
        } else if (hxd.Key.isDown(hxd.Key.A)) {
            this.object.rotate(0, 0, -dt*Math.PI/4);
        }
    }

}
