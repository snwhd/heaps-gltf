

class Main extends hxd.App {

    public static function main() {
        new Main();
    }

    private var avocado: h3d.scene.Object;

    override function init() {
        hxd.Res.initEmbed();
        var lights : h3d.scene.fwd.LightSystem = cast this.s3d.lightSystem;
        lights.ambientLight.set(1.0, 1.0, 1.0);
        this.s3d.camera.pos.set(-10, -10, 10);
        this.s3d.camera.target.set(0, 0, 0);

        var cache = new h3d.prim.ModelCache();
        this.avocado = cache.loadModel(hxd.Res.Avocado);
        this.s3d.addChild(avocado);
    }

    override function update(dt: Float) {
        this.avocado.rotate(0, dt*Math.PI/4, 0);
    }

}
