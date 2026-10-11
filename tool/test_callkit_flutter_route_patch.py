import unittest

from callkit_flutter_route_patch import OLD_BLOCK, NEW_BLOCK, patch_source


class CallkitFlutterRoutePatchTests(unittest.TestCase):
    def test_redirects_native_call_activity_to_flutter(self):
        before = "class CallkitNotificationManager {\n" + OLD_BLOCK + "\n}"
        result = patch_source(before)
        self.assertIn(NEW_BLOCK, result)
        self.assertIn("setContentIntent(getAppPendingIntent", result)
        self.assertIn("setFullScreenIntent(\\n            getAppPendingIntent", result)
        self.assertNotIn("setContentIntent(getActivityPendingIntent", result)
        self.assertEqual(result.count("setFullScreenIntent("), 1)

    def test_stable_if_rerun(self):
        patched = patch_source(OLD_BLOCK)
        self.assertEqual(patch_source(patched), patched)

    def test_fails_closed_on_unrecognized_plugin_source(self):
        with self.assertRaisesRegex(ValueError, "source changed"):
            patch_source("this is a future incompatible CallKit plugin")

    def test_fails_closed_if_source_is_duplicated(self):
        with self.assertRaisesRegex(ValueError, "source changed"):
            patch_source(OLD_BLOCK + "\n" + OLD_BLOCK)


if __name__ == "__main__":
    unittest.main()
