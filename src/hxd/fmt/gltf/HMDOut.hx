package hxd.fmt.gltf;

import h3d.Quat;
import h3d.Vector;
import h3d.col.Bounds;

import hxd.fmt.hmd.Data;
import hxd.fmt.gltf.Data;


class HMDOut {

    private var directory: String;
    private var name: String;
    private var data: Data;

    public function new(name: String, directory: String, data: Data) {
        this.name = name;
        this.directory = directory;
        this.data = data;
    }

    public function toHMD(): hxd.fmt.hmd.Data {
        var outBytes = new haxe.io.BytesOutput();

        // Emit unique combinations of accessors
        // as a single buffer to save data
        var geoMap = new SeqIntMap();
        for (mesh in this.data.meshes) {
            for (prim in mesh.primitives) {
                if (prim.mode != TRIANGLES) {
                    throw "TODO: non-triangle prims?";
                }
                geoMap.add(prim.accList);
            }
        }

        // Map from the entries in geoMap to
        // data positions
        var dataPos = [];
        var bounds = [];

        // Emit one HMD geometry per unique primitive combo
        for (i in 0...geoMap.count) {

            dataPos.push(outBytes.length);
            var bb = new Bounds();
            bb.empty();
            bounds.push(bb);

            var accessors   = geoMap.getList(i);
            var hasNorm     = accessors[NOR]     != -1;
            var hasTex      = accessors[TEX]     != -1;
            var hasJoints   = accessors[JOINTS]  != -1;
            var hasWeights  = accessors[WEIGHTS] != -1;
            var hasIndices  = accessors[INDICES] != -1;
            var hasTangents = accessors[TAN]     != -1;
            var hasGeneratedTangents = false;

            if (!hasNorm && hasIndices) {
                throw "generating normals on indexed models is not supported";
            }
            if (hasJoints != hasWeights) {
                throw "joints/weights mismatch";
            }

            var posAcc  = this.data.accData[accessors[POS]];
            var normAcc = this.data.accData[accessors[NOR]];
            var uvAcc   = this.data.accData[accessors[TEX]];
            var tanAcc  = this.data.accData[accessors[TAN]];

            var genNormals = null;
            if (!hasNorm) {
                genNormals = this.generateNormals(posAcc);
            }

            var generatedTangents: Array<Float> = null;
            if (!hasTangents) {
                var indices: Array<Int> = [];
                if (hasIndices) {
                    var indAcc = this.data.accData[accessors[INDICES]];
                    for (i in 0 ... indAcc.count) {
                        indices.push(Util.getIndex(this.data, indAcc, i));
                    }
                } else {
                    for (i in 0 ... posAcc.count) {
                        indices.push(i);
                    }
                }

                generatedTangents = this.generateTangents(
                    posAcc,
                    normAcc, // TODO: generated normals
                    uvAcc,
                    indices
                );
                if (generatedTangents == null) {
                    throw "failed to generate tangents";
                }
                hasGeneratedTangents = true;
            } else {
                // TODO: force generate tangents?
            }

            var norAcc = this.data.accData[accessors[NOR]];
            var texAcc = this.data.accData[accessors[TEX]];
            var jointAcc  = hasJoints
                ? this.data.accData[accessors[JOINTS]]
                : null;
            var weightAcc = hasWeights
                ? this.data.accData[accessors[WEIGHTS]]
                : null;

            for (i in 0 ... posAcc.count) {
                // write positions
                var x = Util.getFloat(this.data, posAcc, i, 0);
                outBytes.writeFloat(x);
                var y = Util.getFloat(this.data, posAcc, i, 1);
                outBytes.writeFloat(y);
                var z = Util.getFloat(this.data, posAcc, i, 2);
                outBytes.writeFloat(z);
                bb.addPos(x, y, z);

                // write normals
                if (hasNorm) {
                    outBytes.writeFloat(Util.getFloat(this.data, norAcc, i, 0));
                    outBytes.writeFloat(Util.getFloat(this.data, norAcc, i, 1));
                    outBytes.writeFloat(Util.getFloat(this.data, norAcc, i, 2));
                } else {
                    var norm = genNormals[Std.int(i/3)];
                    outBytes.writeFloat(norm.x);
                    outBytes.writeFloat(norm.y);
                    outBytes.writeFloat(norm.z);
                }

                // write tangents
                if (hasTangents) {
                    outBytes.writeFloat(Util.getFloat(this.data, tanAcc, i, 0));
                    outBytes.writeFloat(Util.getFloat(this.data, tanAcc, i, 1));
                    outBytes.writeFloat(Util.getFloat(this.data, tanAcc, i, 2));
                } else if (hasGeneratedTangents) {
                    outBytes.writeFloat(generatedTangents[i*4 + 0]);
                    outBytes.writeFloat(generatedTangents[i*4 + 1]);
                    outBytes.writeFloat(generatedTangents[i*4 + 2]);
                } else {
                    throw "need tangents";
                    // Reserve space for tangent data
                    // (We'll optionally fix it up later)
                    outBytes.writeFloat(0);
                    outBytes.writeFloat(0);
                    outBytes.writeFloat(0);
                }

                // write tex coords
                if (hasTex) {
                    outBytes.writeFloat(Util.getFloat(this.data, texAcc, i, 0));
                    outBytes.writeFloat(Util.getFloat(this.data, texAcc, i, 1));
                } else {
                    outBytes.writeFloat(0.5);
                    outBytes.writeFloat(0.5);
                }

                // write joints
                if (hasJoints) {
                    for (jInd in 0...4) {
                        var joint = Util.getInt(this.data, jointAcc, i, jInd);
                        if (joint < 0) throw "negative joint index";
                        outBytes.writeByte(joint);
                    }
                    //outBytes.writeByte(0);
                }

                // write weights
                if (hasWeights) {
                    for (wInd in 0...4) {
                        var wVal = Util.getFloat(this.data, weightAcc, i, wInd);
                        if (Math.isNaN(wVal)) throw "invalid weight (NaN)";
                        outBytes.writeFloat(wVal);
                    }
                }
            }
        }

        // Find the unique combination of accessor lists in each
        // mesh. This will map on to the HMD geometry concept
        var meshAccLists: Array<Array<Int>> = [];
        for (mesh in this.data.meshes) {
            var accs = Lambda.map(
                mesh.primitives,
                (prim) -> geoMap.add(prim.accList)
            );
            accs.sort((a, b) -> a - b);
            var uniqueAccs = [];
            var last = -1;
            for (a in accs) {
                if (a != last) {
                    uniqueAccs.push(a);
                    last = a;
                }
            }
            meshAccLists.push(uniqueAccs);
        }

        var geos = [];
        var geoMaterials:Array<Array<Int>> = [];

        // Generate a geometry for each mesh-accessor
        // Also retain the materials used
        var meshToGeoMap:Array<Array<Int>> = [];
        for (meshInd in 0 ... this.data.meshes.length) {
            var meshGeoList = [];
            meshToGeoMap.push(meshGeoList);

            var accList = meshAccLists[meshInd];
            for (accSet in accList) {
                var accessors = geoMap.getList(accSet);
                var posAcc = this.data.accData[accessors[0]];

                var geo = new Geometry();
                var geoMats = [];
                meshGeoList.push(geos.length);
                geos.push(geo);
                geoMaterials.push(geoMats);
                geo.props = null;
                geo.vertexCount = posAcc.count;

                var stride = 11;
                var format = [
                    new GeometryFormat("position", DVec3),
                    new GeometryFormat("normal", DVec3),
                    new GeometryFormat("tangent", DVec3),
                    new GeometryFormat("uv", DVec2),
                ];

                if (accessors[3] != -1) {
                    // Has joint and weight data
                    stride += 5;
                    format.push(new GeometryFormat("indexes", DBytes4));
                    format.push(new GeometryFormat("weights", DVec4));
                }

                geo.vertexFormat = hxd.BufferFormat.make(format);
                if (geo.vertexFormat.stride != stride) {
                    throw "unexpected stride";
                }

                geo.vertexPosition = dataPos[accSet];
                geo.bounds = bounds[accSet];

                var mesh = this.data.meshes[meshInd];

                // @todo

                var indexList = [];
                // Iterate the primitives and add indices for this geo
                for (prim in mesh.primitives) {
                    var primAccInd = geoMap.add(prim.accList);
                    if (accSet != primAccInd)
                        continue; // Different geo

                    var matInd = geoMats.indexOf(prim.matInd);
                    if (matInd == -1) {
                        // First use of this mat
                        matInd = geoMats.length;
                        geoMats.push(prim.matInd);
                        indexList.push([]);
                    }

                    // Fill the index list
                    if (prim.indices != null) {
                        var iList = indexList[matInd];
                        var indexAcc = this.data.accData[prim.indices];
                        for (i in 0...indexAcc.count) {
                            iList.push(Util.getIndex(this.data, indexAcc, i));
                        }
                    } else {
                        indexList[matInd] = [for (i in 0...geo.vertexCount) i];
                    }
                }

                // Emit the indices
                var is32 = geo.vertexCount > 0x10000;

                geo.indexPosition = outBytes.length;
                geo.indexCounts = Lambda.map(indexList, (x) -> x.length);
                if (is32) {
                    for (inds in indexList) {
                        for (i in inds) {
                            outBytes.writeInt32(i);
                        }
                    }
                } else {
                    for (inds in indexList) {
                        for (i in inds) {
                            outBytes.writeUInt16(i);
                        }
                    }
                }
            }
        }

        var inlineImages = [];
        var materials = [];
        for (matInd in 0 ... this.data.mats.length) {
            var mat = this.data.mats[matInd];
            var hMat = new hxd.fmt.hmd.Material();
            hMat.name = mat.name;

            if (mat.colorTex != null) {
                switch(mat.colorTex) {
                    case File(filename):
                        hMat.diffuseTexture = haxe.io.Path.join([
                            this.directory,
                            filename
                        ]);
                    case Buffer(buff, pos, len, ext): {
                        inlineImages.push({
                            buff: buff,
                            pos: pos,
                            len: len,
                            ext: ext,
                            mat: matInd
                        });
                    }
                }
            #if !heaps_gltf_disable_material_patch
            } else if (mat.color != null) {
                hMat.diffuseTexture = Util.toColorString(mat.color);
            } else {
                hMat.diffuseTexture = Util.toColorString(0);
            #end
            }
            hMat.blendMode = None;
            materials.push(hMat);
        }

        var identPos = new hxd.fmt.hmd.Position();
        Util.initializePosition( identPos );

        var models = [];
        var rootModel = new Model();
        rootModel.name = this.name;
        rootModel.props = null;
        rootModel.parent = -1;
        rootModel.follow = null;
        rootModel.position = identPos;
        rootModel.skin = null;
        rootModel.geometry = -1;
        rootModel.materials = null;
        models[0] = rootModel;

        var nextOutID = 1;
        for (n in this.data.nodes) {
            // Mark the slot the node will be put into
            // while skipping over joints
            if (!n.isJoint) {
                n.outputID = nextOutID++;
            }
        }

        for (i in 0 ... this.data.nodes.length) {
            // sanity check
            var node = this.data.nodes[i];
            if (node.nodeInd != i) {
                throw 'invalid nodex index ${node.nodeInd} != $i';
            } else if (node.isJoint) continue;

            var model = new Model();
            model.name = node.name;
            model.props = null;
            model.parent = node.parent != null ? node.parent.outputID: 0;
            model.follow = null;
            model.position = this.nodeToPos(node);
            model.skin = null;
            if (node.mesh != null) {
                if (node.skin != null) {
                    model.skin = this.buildSkin(
                        this.data.skins[node.skin],
                        node.name
                    );
                    //model.skin = null;
                }

                var geoList = meshToGeoMap[node.mesh];
                if (geoList.length == 1) {
                    // We can put the single geometry in this node
                    model.geometry = geoList[0];
                    model.materials = geoMaterials[geoList[0]];
                } else {
                    model.geometry = -1;
                    model.materials = null;
                    // We need to generate a model per primitive
                    for (geoInd in geoList) {
                        var primModel = new Model();
                        primModel.name = this.data.meshes[node.mesh].name;
                        primModel.props = null;
                        primModel.parent = node.outputID;
                        primModel.position = identPos;
                        primModel.follow = null;
                        primModel.skin = null;
                        primModel.geometry = geoInd;
                        primModel.materials = geoMaterials[geoInd];
                        models[nextOutID++] = primModel;
                    }
                }
            } else {
                model.geometry = -1;
                model.materials = null;
            }
            models[node.outputID] = model;
        }

        // Populate animation information and fill data
        var anims = [];
        for (animData in this.data.animations) {
            var anim = new hxd.fmt.hmd.Data.Animation();
            anim.name = animData.name;
            anim.props = null;
            anim.frames = animData.numFrames;
            anim.sampling = Data.SAMPLE_RATE;
            anim.speed = 1.0;
            anim.loop = false;
            anim.objects = [];
            for (curveData in animData.curves) {
                var animObject = new hxd.fmt.hmd.Data.AnimationObject();
                animObject.name = curveData.targetName;

                if (curveData.transValues != null) {
                    animObject.flags.set(HasPosition);
                }
                if (curveData.rotValues != null) {
                    animObject.flags.set(HasRotation);
                }
                if (curveData.scaleValues != null) {
                    animObject.flags.set(HasScale);
                }
                anim.objects.push(animObject);
            }
            // Fill in the animation data
            anim.dataPosition = outBytes.length;
            for (f in 0 ... anim.frames) {
                for (curve in animData.curves) {

                    if (curve.transValues != null) {
                        outBytes.writeFloat(curve.transValues[f*3+0]);
                        outBytes.writeFloat(curve.transValues[f*3+1]);
                        outBytes.writeFloat(curve.transValues[f*3+2]);
                    }

                    if (curve.rotValues != null) {
                        var quat = new Quat(
                            curve.rotValues[f*4+0],
                            curve.rotValues[f*4+1],
                            curve.rotValues[f*4+2],
                            curve.rotValues[f*4+3]);
                        var qLength = quat.length();

                        if (Math.abs(qLength-1.0) >= 0.2) {
                            throw "invalid animation curve";
                        }

                        quat.normalize();
                        if (quat.w < 0) {
                            quat.w*= -1;
                            quat.x*= -1;
                            quat.y*= -1;
                            quat.z*= -1;
                        }
                        outBytes.writeFloat(quat.x);
                        outBytes.writeFloat(quat.y);
                        outBytes.writeFloat(quat.z);
                    }

                    if (curve.scaleValues != null) {
                        outBytes.writeFloat(curve.scaleValues[f*3+0]);
                        outBytes.writeFloat(curve.scaleValues[f*3+1]);
                        outBytes.writeFloat(curve.scaleValues[f*3+2]);
                    }
                }
            }
            anims.push(anim);
        }

        // Append any inline images to the binary data
        for (img in inlineImages) {
            // Generate a new texture string using the relative-texture format
            var mat = materials[img.mat];
            mat.diffuseTexture = '${img.ext}@${outBytes.length}--${img.len}';

            var imageBytes = this.data.bufferData[img.buff].sub(
                img.pos,
                img.len
            );
            outBytes.writeBytes(imageBytes, 0, img.len);
        }

        var ret = new hxd.fmt.hmd.Data();

        #if hmd_version
        ret.version = Std.parseInt(
            #if macro
            haxe.macro.Context.definedValue("hmd_version")
            #else
            haxe.macro.Compiler.getDefine("hmd_version")
            #end
        );
        #else
        ret.version = hxd.fmt.hmd.Data.CURRENT_VERSION;
        #end

        ret.props = null;
        ret.materials = materials;
        ret.geometries = geos;
        ret.models = models;
        ret.animations = anims;
        ret.dataPosition = 0;
        ret.data = outBytes.getBytes();
        return ret;
    }

    function makePosition(m: h3d.Matrix) {
        var p = new Position();
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

    // Keep high precision values.
    // Might increase animation data size and compressed size.
    public var highPrecision : Bool = false;

    function round(v:Float) {
        if (v != v) throw "NaN found";
        return highPrecision ? v : std.Math.fround(v * 131072) / 131072;
    }

    function buildSkin(skin:SkinData, nodeName): hxd.fmt.hmd.Data.Skin {
        var ret = new hxd.fmt.hmd.Data.Skin();
        ret.name = (
            skin.skeleton != null
            ? this.data.nodes[skin.skeleton].name
            : nodeName
        ) + "_skin";
        ret.props = [FourBonesByVertex]; // @todo should this go here or in sj?
        ret.split = null;
        ret.joints = [];

        for (i in 0...skin.joints.length) {
            var jInd = skin.joints[i];
            var node = this.data.nodes[jInd];

            var sj = new hxd.fmt.hmd.Data.SkinJoint();
            sj.name = node.name;
            sj.props = null;
            sj.position = this.nodeToPos(node);
            sj.parent = skin.joints.indexOf(node.parent.nodeInd);
            sj.bind = i;

            // Get invBindMatrix
            var invBindMat = Util.getMatrix(
                this.data,
                this.data.accData[skin.invBindMatAcc],
                i
            );
            sj.transpos = Util.posFromMatrix(invBindMat);

            // Copied from the FBX loader... Oh no......
            if (
                sj.transpos.sx != 1 ||
                sj.transpos.sy != 1 ||
                sj.transpos.sz != 1
            ) {
                // FIX: the scale is not correctly taken into account,
                // this formula will extract it and fix things
                var tmp = Util.posFromMatrix(invBindMat).toMatrix();
                tmp.transpose();
                var s = tmp.getScale();
                tmp.prependScale(1 / s.x, 1 / s.y, 1 / s.z);
                tmp.transpose();
                sj.transpos = this.makePosition(tmp);
                sj.transpos.sx = this.round(s.x);
                sj.transpos.sy = this.round(s.y);
                sj.transpos.sz = this.round(s.z);
            }

            // Ensure this matrix converted to a 'Position' correctly
            var testMat = sj.transpos.toMatrix();
            //var testPos = Position.fromMatrix(testMat);
            //if (!Util.matNear(invBindMat, testMat)) throw "";
            ret.joints.push(sj);
        }

        return ret;
    }

    function generateNormals(posAcc:BuffAccess) : Array<Vector> {
        if (posAcc.count % 3 != 0) throw "bad position accessor length";
        var numTris = Std.int(posAcc.count / 3);
        var ret = [];

        for (i in 0...numTris) {
            var ps = [];
            for (p in 0...3) {
                ps.push(new Vector(
                    Util.getFloat(this.data, posAcc, i*3+p,0),
                    Util.getFloat(this.data, posAcc, i*3+p,1),
                    Util.getFloat(this.data, posAcc, i*3+p,2)
                ));
            }
            var d0 = ps[1].sub(ps[0]);
            var d1 = ps[2].sub(ps[1]);
            ret.push(d0.cross(d1));
        }

        return ret;
    }

    function nodeToPos(node: NodeData): Position {
        var ret = new Position();

        if (node.trans != null) {
            ret.x = node.trans.x;
            ret.y = node.trans.y;
            ret.z = node.trans.z;
        } else {
            ret.x = 0.0;
            ret.y = 0.0;
            ret.z = 0.0;
        }
        if (node.rot != null) {
            var posW = node.rot.w > 0.0;
            ret.qx = node.rot.x * (posW?1.0:-1.0);
            ret.qy = node.rot.y * (posW?1.0:-1.0);
            ret.qz = node.rot.z * (posW?1.0:-1.0);
        } else {
            ret.qx = 0.0;
            ret.qy = 0.0;
            ret.qz = 0.0;
        }
        if (node.scale != null) {
            ret.sx = node.scale.x;
            ret.sy = node.scale.y;
            ret.sz = node.scale.z;
        } else {
            ret.sx = 1.0;
            ret.sy = 1.0;
            ret.sz = 1.0;
        }

        return ret;
    }

    function generateTangents(
        posAcc: BuffAccess,
        normAcc: BuffAccess,
        uvAcc: BuffAccess,
        indices: Array<Int>
    ): Array<Float> {

        #if (hl && !hl_disable_mikkt && (haxe_ver >= "4.0"))
        //
        // hashlink - use built in mikktospace
        //
        if (normAcc == null) throw "TODO: generated normals";

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
            m.buffer[out++] = Util.getFloat(this.data, posAcc, vidx, 0);
            m.buffer[out++] = Util.getFloat(this.data, posAcc, vidx, 1);
            m.buffer[out++] = Util.getFloat(this.data, posAcc, vidx, 2);

            m.buffer[out++] = Util.getFloat(this.data, normAcc, vidx, 0);
            m.buffer[out++] = Util.getFloat(this.data, normAcc, vidx, 1);
            m.buffer[out++] = Util.getFloat(this.data, normAcc, vidx, 2);

            m.buffer[out++] = Util.getFloat(this.data, uvAcc, vidx, 0);
            m.buffer[out++] = Util.getFloat(this.data, uvAcc, vidx, 1);

            m.tangents[i<<2] = 1;
            m.indexes[i] = i;
        }

        m.compute();

        var arr: Array<Float> = [];
        for (i in 0 ... indices.length*4) {
            arr[i] = m.tangents[i];
        }
        return arr;

        #elseif (sys || nodejs)
        //
        // sys/nodejs - shell out to system mikktspace
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
            dataBuffer.addFloat(Util.getFloat(this.data, posAcc, vidx, 0));
            dataBuffer.addFloat(Util.getFloat(this.data, posAcc, vidx, 1));
            dataBuffer.addFloat(Util.getFloat(this.data, posAcc, vidx, 2));

            dataBuffer.addFloat(Util.getFloat(this.data, normAcc, vidx, 0));
            dataBuffer.addFloat(Util.getFloat(this.data, normAcc, vidx, 1));
            dataBuffer.addFloat(Util.getFloat(this.data, normAcc, vidx, 2));

            dataBuffer.addFloat(Util.getFloat(this.data, uvAcc, vidx, 0));
            dataBuffer.addFloat(Util.getFloat(this.data, uvAcc, vidx, 1));
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

        #else

        throw "Tangent generation is not supported on this platform";

        #end
    }

    public static function emitHMD(
        name: String,
        directory: String,
        data: Data
    ): hxd.fmt.hmd.Data {
        var out = new HMDOut(name, directory, data);
        return out.toHMD();
    }

}
