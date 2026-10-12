"""Exercise the exact Python scripts embedded in emergency VPS updater.

Regression against comment-prefixed SQL (106 deployment failure) and
unintended overwriting of production QR/call hotfixes.
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
SCRIPT=(ROOT/"deploy/motorcycle-emergency-live.sh").read_text()
SQL=ROOT/"server/migrations/107_motorcycle_emergency_cards.sql"
LIVE=ROOT/"server"

def python_heredoc(marker):
    m=re.search(
        re.escape(marker)+r" <<'PY'\n(.*?)\nPY",
        SCRIPT,re.DOTALL
    )
    if not m:
        raise AssertionError("Missing Python deployment snippet: "+marker)
    return m.group(1)

class EmergencyDeployTests(unittest.TestCase):
    def test_sql_with_comments_is_transactional(self):
        code=python_heredoc('python3 - "$TMP/server/migrations/$MIGRATION" "$TMP/install.sql" "$CHECKSUM" "$TRACKING"')
        for tracking in ('t','f'):
            with self.subTest(tracking=tracking),tempfile.TemporaryDirectory() as d:
                target=Path(d)/"install.sql"
                r=subprocess.run([sys.executable,"-c",code,str(SQL),str(target),"a"*64,tracking],
                                 capture_output=True,text=True)
                self.assertEqual(r.returncode,0,r.stderr)
                sql=target.read_text()
                self.assertTrue(sql.startswith("BEGIN;\n"))
                self.assertIn("vehicle_motorcycle_emergency_cards",sql)
                self.assertEqual(len(re.findall(r"(?m)^COMMIT;",sql)),1)
                self.assertEqual(len(re.findall(r"(?m)^BEGIN;",sql)),1)
                self.assertTrue(sql.rstrip().endswith("COMMIT;"))
                self.assertEqual(sql.count("INSERT INTO public.schema_migrations"),1 if tracking=='t' else 0)

    def test_patching_existing_live_files_is_minimal_and_idempotent(self):
        code=python_heredoc('python3 - "$ROOT" "$TMP"')
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)/"live"
            tmp=Path(d)/"tmp"
            root.mkdir()
            tmp.mkdir()
            files=("server.js","vehicle-transfer-service.js","vehicle-management-routes.js")
            for f in files:
                (root/f).write_text((LIVE/f).read_text()+"\n// VPS_CUSTOM_QR_AND_CALL_FIX\n")
            # Simulate old live server that has motorcycle profiles but not emergency API.
            old=(root/"server.js").read_text()
            old=old.replace("const registerMotorcycleEmergencyRoutes=require('./motorcycle-emergency-routes');\n","")
            old=old.replace("registerMotorcycleEmergencyRoutes(app,pool);\n","")
            (root/"server.js").write_text(old)
            old=(root/"vehicle-transfer-service.js").read_text()
            old=re.sub(r"\s*// Sensitive rider and third-party contact details belong to the OLD owner\.\n\s*await db\.query\('DELETE FROM vehicle_motorcycle_emergency_cards WHERE vehicle_id::text=\$1',\[vehicle\]\);","",old)
            (root/"vehicle-transfer-service.js").write_text(old)
            old=(root/"vehicle-management-routes.js").read_text()
            old=re.sub(r"\s*if\(vehicleType!=='motorcycle'\)await client\.query\(\n\s*'DELETE FROM vehicle_motorcycle_emergency_cards WHERE vehicle_id::text=\$1',\[vehicleId\]\);","",old)
            (root/"vehicle-management-routes.js").write_text(old)
            for count in range(2):
                r=subprocess.run([sys.executable,"-c",code,str(root),str(tmp)],
                                 capture_output=True,text=True)
                self.assertEqual(r.returncode,0,r.stderr)
                for f in files:
                    content=(tmp/f).read_text()
                    self.assertIn("VPS_CUSTOM_QR_AND_CALL_FIX",content)
                    (root/f).write_text(content)
                self.assertEqual((root/"server.js").read_text().count("registerMotorcycleEmergencyRoutes(app,pool);"),1)
                self.assertEqual((root/"vehicle-transfer-service.js").read_text().count("DELETE FROM vehicle_motorcycle_emergency_cards"),1)
                self.assertEqual((root/"vehicle-management-routes.js").read_text().count("DELETE FROM vehicle_motorcycle_emergency_cards"),1)

if __name__=="__main__":
    unittest.main()
