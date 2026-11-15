const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const DAY = 24 * 60 * 60 * 1000;
// Keep this aligned with feeReminderAfterDue in lib/notification_inbox.dart.
const REMIND_AGAIN_AFTER_DAYS = 3;

function dayKey(date) {
  return date.toISOString().slice(0, 10);
}

function isDueTodayOrOverdue(enrolledAt, now) {
  const start = Date.parse(enrolledAt);
  if (Number.isNaN(start)) return false;
  const due = new Date(start);
  due.setHours(0, 0, 0, 0);
  const today = new Date(now);
  today.setHours(0, 0, 0, 0);
  const late = new Date(today.getTime() - REMIND_AGAIN_AFTER_DAYS * DAY);
  const dueKey = dayKey(due);
  return dueKey === dayKey(today) || dueKey === dayKey(late);
}

async function notifyUser(uid, title, body, kind, noteId, push = true) {
  const db = getFirestore();
  const notes = db.collection('profiles').doc(uid).collection('notifications');
  const payload = {
    title,
    body,
    kind,
    read: false,
    createdAt: Timestamp.now(),
  };
  if (noteId) {
    const existing = await notes.doc(noteId).get();
    if (existing.exists) return;
    await notes.doc(noteId).set(payload);
  } else {
    await notes.add(payload);
  }
  if (!push) return;
  const profile = await db.collection('profiles').doc(uid).get();
  const tokens = profile.get('fcmTokens') || [];
  if (!Array.isArray(tokens) || tokens.length === 0) return;
  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
  });
  const stale = [];
  response.responses.forEach((item, index) => {
    if (item.error && item.error.code === 'messaging/registration-token-not-registered') {
      stale.push(tokens[index]);
    }
  });
  if (stale.length > 0) {
    await db.collection('profiles').doc(uid).update({
      fcmTokens: tokens.filter((token) => !stale.includes(token)),
    });
  }
}

exports.feeReminders = onSchedule('every day 09:00', async () => {
  const db = getFirestore();
  const now = new Date();
  const listings = await db.collection('listings').get();
  for (const listing of listings.docs) {
    const title = listing.get('title') || 'Your class';
    const fees = await listing.ref.collection('fees').get();
    for (const fee of fees.docs) {
      const due = Number(fee.get('unitAmount') || 0) * Number(fee.get('monthsBilled') || 1);
      const paid = Number(fee.get('amountPaid') || 0);
      if (due <= 0 || paid >= due) continue;
      if (!isDueTodayOrOverdue(fee.get('enrolledAt') || '', now)) continue;
      const pending = due - paid;
      const enrolment = await listing.ref.collection('enrollments').doc(fee.get('mcId')).get();
      const userId = enrolment.get('userId');
      if (!userId || String(userId).startsWith('demo_')) continue;
      await notifyUser(
        userId,
        'Fee pending',
        `${title}: ₹${pending} is still pending for ${fee.get('attendeeName') || 'an attendee'}.`,
        'fee_due',
      );
    }
  }
});

exports.interestNotice = onDocumentCreated(
  'listings/{listingId}/interests/{userId}',
  async (event) => {
    const data = event.data ? event.data.data() : null;
    if (!data || data.status !== 'interested') return;
    const listingId = event.params.listingId;
    const learnerId = event.params.userId;
    const db = getFirestore();
    const listing = await db.collection('listings').doc(listingId).get();
    const masterId = listing.get('creatorId');
    if (!masterId || masterId === learnerId || String(masterId).startsWith('demo_')) return;
    const classTitle = listing.get('title') || data.listingTitle || 'your class';
    const learner = data.userName || 'A learner';
    const mcId = data.mcId ? ` (${data.mcId})` : '';
    await notifyUser(
      masterId,
      'New interest',
      `${learner}${mcId} wants to join ${classTitle}.`,
      'interest',
    );
  },
);

function citySlug(city) {
  return String(city || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function sameCity(left, right) {
  const a = String(left || '').trim().toLowerCase();
  const b = String(right || '').trim().toLowerCase();
  return a.length > 0 && a === b;
}

function istDayKey(offsetDays) {
  const istMillis = Date.now() + 5.5 * 60 * 60 * 1000 + offsetDays * DAY;
  return new Date(istMillis).toISOString().slice(0, 10);
}

// 03:30 UTC is 09:00 IST.
exports.eventReminders = onSchedule({ schedule: '30 3 * * *', timeZone: 'UTC' }, async () => {
  const db = getFirestore();
  const tomorrow = istDayKey(1);
  const listings = await db.collection('listings').where('start_date', '==', tomorrow).get();
  const profiles = await db.collection('profiles').get();
  for (const listing of listings.docs) {
    if (String(listing.id).startsWith('demo_')) continue;
    const format = listing.get('listing_type') || listing.get('type') || '';
    if (format !== 'event') continue;
    const eventCity = listing.get('city') || '';
    const slug = citySlug(eventCity);
    if (!slug) continue;
    const markerRef = db.collection('eventReminders').doc(`${listing.id}_${tomorrow}`);
    if ((await markerRef.get()).exists) continue;
    const title = listing.get('title') || 'An event';
    const body = `${title} is in ${eventCity} tomorrow.`;
    for (const profile of profiles.docs) {
      const uid = profile.id;
      if (String(uid).startsWith('demo_')) continue;
      const matches =
        sameCity(profile.get('city'), eventCity) ||
        sameCity(profile.get('preferredEventCity'), eventCity);
      if (!matches) continue;
      await notifyUser(
        uid,
        'Event tomorrow',
        body,
        'event_reminder',
        `event_${listing.id}_${tomorrow}`,
        false,
      );
    }
    try {
      await getMessaging().send({
        topic: `city_${slug}`,
        notification: { title: 'Event tomorrow', body },
      });
    } catch (error) {
      console.error('Event topic push failed', listing.id, error);
    }
    await markerRef.set({
      listingId: listing.id,
      city: eventCity,
      date: tomorrow,
      sentAt: Timestamp.now(),
    });
  }
});

exports.announce = onDocumentCreated('listings/{listingId}/announcements/{announcementId}', async (event) => {
  const data = event.data ? event.data.data() : null;
  if (!data) return;
  const listingId = event.params.listingId;
  const db = getFirestore();
  const listing = await db.collection('listings').doc(listingId).get();
  const classTitle = listing.get('title') || 'Your class';
  const batchId = data.batchId || '';
  const enrolments = await db.collection('listings').doc(listingId).collection('enrollments').get();
  for (const enrolment of enrolments.docs) {
    const attendees = enrolment.get('attendees') || [];
    const included = !batchId || attendees.some((person) => person && person.batchId === batchId);
    const userId = enrolment.get('userId');
    if (!included || !userId || String(userId).startsWith('demo_')) continue;
    await notifyUser(
      userId,
      data.title || classTitle,
      data.body || `New announcement in ${classTitle}.`,
      'announcement',
    );
  }
});
