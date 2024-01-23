

class Main extends hxd.App {

    public static function main() {
        new Main();
    }

    private var avocado: h3d.scene.Object;

    override function init() {
        hxd.Res.initEmbed();
        var lights : h3d.scene.fwd.LightSystem = cast this.s3d.lightSystem;
        lights.ambientLight.set(1.0, 1.0, 1.0);
        this.s3d.camera.pos.set(0.0, -0.25, 0.0);
        this.s3d.camera.target.set(0, 0, 0);

        var cache = new h3d.prim.ModelCache();
        this.avocado = cache.loadModel(hxd.Res.loader.load("Avocado.gltf").toModel());
        this.avocado.rotate(Math.PI/2, 0, 0);
        this.avocado.getChildAt(0).toMesh().material.shadows = false;
        this.avocado.z = -0.035;
        this.s3d.addChild(avocado);
    }

    override function update(dt: Float) {
        this.avocado.rotate(0, 0, dt*Math.PI/4);
    }

}
