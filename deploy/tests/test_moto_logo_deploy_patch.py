"""Validate the exact Python code used to patch VPS logo modules.

A previous deployment broke at SQL parsing. This test executes the actual
deploy heredoc against a simulated older VPS instead of trusting shell syntax.
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "deploy" / "motorcycle-brand-logos-live.sh"
SERVICE = ROOT / "server" / "vehicle-brand-logo-service.js"
ROUTES = ROOT / "server" / "vehicle-management-routes.js"

class MotorcycleLogoDeployTest(unittest.TestCase):
    def extract_code(self):
        script = SCRIPT.read_text()
        match = re.search(
            r'python3 - "\$ROOT/vehicle-brand-logo-service.js".*?<<\x27PY\x27\n'
            r"(.*?)\nPY",
            script,
            re.DOTALL,
        )
        self.assertIsNotNone(match)
        return match.group(1)

    def run_patch(self, service_text, routes_text):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            old_service=base/"old-service.js"
            new_service=base/"new-service.js"
            old_routes=base/"old-routes.js"
            out_service=base/"out-service.js"
            out_routes=base/"out-routes.js"
            old_service.write_text(service_text)
            new_service.write_text(SERVICE.read_text())
            old_routes.write_text(routes_text)
            result=subprocess.run(
                [sys.executable,"-c",self.extract_code(),
                 str(old_service),str(new_service),str(old_routes),
                 str(out_service),str(out_routes)],
                capture_output=True,text=True,check=False,
            )
            return result, out_service.read_text() if out_service.exists() else "", \
                out_routes.read_text() if out_routes.exists() else ""

    def test_preserves_other_live_functions_and_inserts_logo_resolver(self):
        latest=SERVICE.read_text()
        anchor="const {motorcycleLogoSource}=require('./motorcycle-brand-logo-source');"
        from_part="async function resolveExternal("
        to_part="module.exports={normalizeBrand,findBrand,logoPayload,cachedLogo,resolveExternal,queueResolve,publicBase,imageMeta,assertPublicHttps};"
        x,y=latest.index(from_part),latest.index(to_part)
        old=latest.replace(anchor,"")
        old=old[:old.index(from_part)]+(
            "async function resolveExternal(pool,brand,base){return brand;}\n"
            "function queueResolve(pool,make,base){}\n"
        )+old[old.index(to_part):]
        old=old.replace(
            "const NEGATIVE_TTL_MS=7*24*60*60*1000;",
            "const NEGATIVE_TTL_MS=7*24*60*60*1000;\n// KEEP_VPS_HOTFIX",
        )
        live_routes=ROUTES.read_text()
        live_routes=live_routes.replace(
            "queueResolve(pool,v.make,base,{vehicleType:v.vehicle_type});",
            "queueResolve(pool,v.make,base);"
        ).replace(
            "queueResolve(pool,created.rows[0].make,publicBase(req),{vehicleType:created.rows[0].vehicle_type});",
            "queueResolve(pool,created.rows[0].make,publicBase(req));"
        ).replace(
            "queueResolve(pool,updated.rows[0].make,publicBase(req),{vehicleType:updated.rows[0].vehicle_type});",
            "queueResolve(pool,updated.rows[0].make,publicBase(req));"
        )
        result,service,routes=self.run_patch(old,live_routes)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn("KEEP_VPS_HOTFIX",service)
        self.assertIn(anchor,service)
        self.assertIn("motorcycleLogoSource(brand.name,vehicleType)",service)
        self.assertIn("vehicleType:v.vehicle_type",routes)
        self.assertIn("vehicleType:created.rows[0].vehicle_type",routes)
        self.assertIn("vehicleType:updated.rows[0].vehicle_type",routes)

    def test_running_patch_again_is_idempotent(self):
        result,service,routes=self.run_patch(
            SERVICE.read_text(),ROUTES.read_text()
        )
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(service,SERVICE.read_text())
        self.assertEqual(routes,ROUTES.read_text())

if __name__=="__main__":
    unittest.main()
