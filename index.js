const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.syncNotes = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set("Access-Control-Allow-Origin", "*");

  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type, x-user-id");
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({error: "Method not allowed"});
    return;
  }

  try {
    const userId = req.headers["x-user-id"];
    const noteData = req.body;

    if (!userId) {
      res.status(401).json({error: "Missing user ID"});
      return;
    }

    if (!noteData.id || !noteData.title) {
      res.status(400).json({error: "Missing required fields"});
      return;
    }

    // Save to Firestore
    await admin.firestore()
        .collection("notes")
        .doc(noteData.id)
        .set({
          ...noteData,
          userId,
          syncedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

    res.status(200).json({
      success: true,
      message: "Note synced successfully",
    });
  } catch (error) {
    console.error("Error syncing note:", error);
    res.status(500).json({
      error: "Internal server error",
      details: error.message,
    });
  }
});
