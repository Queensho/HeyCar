"""Run the exact SQL preparer embedded in the live deploy script.

Regression for MIGRATION_BEGIN_MISSING: the tracked SQL begins with comments
before BEGIN, and the live deploy must accept it without modifying schema or
losing the checksum migration-tracking insert.
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "deploy" / "motorcycle-profile-live.sh"
MIGRATION = ROOT / "server" / "migrations" / "106_motorcycle_service_profile.sql"


class MotorcycleMigrationParserTest(unittest.TestCase):
    def _sql_preparer(self):
        content = SCRIPT.read_text()
        match = re.search(
            r"python3 - \"\$TMP/server/migrations/\$MIGRATION\" "
            r"\"\$TMP/install.sql\" \"\$CHECKSUM\" \"\$TRACKING\" <<'PY'\n"
            r"(.*?)\nPY",
            content,
            re.DOTALL,
        )
        self.assertIsNotNone(match, "Could not locate actual live SQL preparer")
        return match.group(1)

    def _prepare(self, tracked):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "install.sql"
            result = subprocess.run(
                [
                    sys.executable,
                    "-c",
                    self._sql_preparer(),
                    str(MIGRATION),
                    str(output),
                    "a" * 64,
                    "t" if tracked else "f",
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            return output.read_text()

    def test_migration_with_leading_comments_preserves_transaction(self):
        sql = self._prepare(tracked=False)
        self.assertTrue(sql.startswith("BEGIN;\n"), sql[:100])
        self.assertIn("CREATE TABLE IF NOT EXISTS public.vehicle_motorcycle_profiles", sql)
        self.assertIn("GRANT SELECT,INSERT,UPDATE,DELETE", sql)
        self.assertEqual(len(re.findall(r"(?m)^\s*BEGIN;", sql)), 1)
        self.assertEqual(len(re.findall(r"(?m)^\s*COMMIT;", sql)), 1)
        self.assertTrue(sql.rstrip().endswith("COMMIT;"))

    def test_schema_tracking_and_migration_are_one_transaction(self):
        sql = self._prepare(tracked=True)
        self.assertEqual(sql.count("INSERT INTO public.schema_migrations"), 1)
        self.assertIn("VALUES('106_motorcycle_service_profile.sql','" + "a" * 64 + "')", sql)
        self.assertLess(
            sql.index("CREATE TABLE IF NOT EXISTS public.vehicle_motorcycle_profiles"),
            sql.index("INSERT INTO public.schema_migrations"),
        )
        self.assertLess(sql.index("INSERT INTO public.schema_migrations"), sql.rfind("COMMIT;"))


if __name__ == "__main__":
    unittest.main()
