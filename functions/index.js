const { setGlobalOptions } = require("firebase-functions");
const { onSchedule } = require("firebase-functions/v2/pubsub");
const admin = require("firebase-admin");
admin.initializeApp();

// Limit maximum container instances
setGlobalOptions({ maxInstances: 10 });

// Fungsi untuk hantar reminder vaksin setiap 1 minit
exports.sendVaccineReminders = onSchedule("every 1 minutes", async (event) => {
  const now = new Date();
  console.log("Checking vaccine reminders at:", now);

  try {
    const snapshots = await admin.firestore()
      .collectionGroup('selectedVaccines')
      .where('scheduleDate', '<=', now)
      .where('notified', '==', false)
      .get();

    if (snapshots.empty) {
      console.log("No pending reminders.");
      return;
    }

    for (const doc of snapshots.docs) {
      const data = doc.data();
      if (!data.fcmToken) continue;

      // Hantar notification
      await admin.messaging().send({
        token: data.fcmToken,
        notification: {
          title: "Reminder Vaksin",
          body: `Vaksin ${data.vaccineName} adalah hari ini!`
        }
      });

      // Update notified = true supaya tak hantar dua kali
      await doc.ref.update({ notified: true });
      console.log(`Notification sent for ${data.vaccineName}`);
    }
  } catch (error) {
    console.error("Error sending reminders:", error);
  }
});
