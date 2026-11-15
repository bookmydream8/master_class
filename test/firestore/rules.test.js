const { readFileSync } = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  Timestamp,
} = require('firebase/firestore');

const projectId = 'demo-master-class';
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

function db(uid) {
  return uid
    ? testEnv.authenticatedContext(uid).firestore()
    : testEnv.unauthenticatedContext().firestore();
}

async function seed(writer) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await writer(context.firestore());
  });
}

const now = () => Timestamp.now();

test('listings are public to read and only the owner can change them', async () => {
  await assertSucceeds(setDoc(doc(db('master'), 'listings/class1'), {
    creatorId: 'master',
    title: 'Tabla hands-on',
  }));
  await assertSucceeds(getDoc(doc(db(null), 'listings/class1')));
  await assertFails(setDoc(doc(db('learner'), 'listings/class1'), {
    creatorId: 'learner',
    title: 'Taken over',
  }));
  await assertFails(deleteDoc(doc(db('learner'), 'listings/class1')));
  await assertSucceeds(updateDoc(doc(db('master'), 'listings/class1'), { title: 'Tabla, evening' }));
});

test('an admin can delete a listing and nobody can grant themselves admin', async () => {
  await seed(async (adminDb) => {
    await setDoc(doc(adminDb, 'listings/class1'), { creatorId: 'master', title: 'Tabla' });
    await setDoc(doc(adminDb, 'admins/admin1'), { note: 'console' });
  });
  await assertFails(setDoc(doc(db('learner'), 'admins/learner'), { note: 'no' }));
  await assertFails(getDoc(doc(db('learner'), 'admins/admin1')));
  await assertSucceeds(getDoc(doc(db('admin1'), 'admins/admin1')));
  await assertSucceeds(deleteDoc(doc(db('admin1'), 'listings/class1')));
});

test('the MC ID counter only moves forward by one', async () => {
  await assertFails(setDoc(doc(db(null), 'counters/memberId'), { next: 100001 }));
  await assertSucceeds(setDoc(doc(db('learner'), 'counters/memberId'), { next: 100001 }));
  await assertFails(updateDoc(doc(db('learner'), 'counters/memberId'), { next: 100245 }));
  await assertFails(setDoc(doc(db('learner'), 'counters/memberId'), { next: 100002, extra: true }));
  await assertSucceeds(updateDoc(doc(db('other'), 'counters/memberId'), { next: 100002 }));
  await assertFails(deleteDoc(doc(db('other'), 'counters/memberId')));
});

test('a profile MC ID cannot be changed once it is set', async () => {
  const learner = db('learner');
  await assertFails(getDoc(doc(db(null), 'profiles/learner')));
  await assertSucceeds(setDoc(doc(learner, 'profiles/learner'), {
    mcId: 'MC100245',
    uid: 'learner',
    role: 'Learner',
    upiId: 'learner@oksbi',
    topicInterests: ['Music'],
    updatedAt: now(),
  }));
  await assertFails(updateDoc(doc(learner, 'profiles/learner'), { mcId: 'MC100999' }));
  await assertSucceeds(updateDoc(doc(learner, 'profiles/learner'), {
    city: 'Bangalore',
    fcmTokens: ['token-a'],
    updatedAt: now(),
  }));
  await assertFails(setDoc(doc(db('other'), 'profiles/learner'), { city: 'Elsewhere' }));
  await assertSucceeds(getDoc(doc(db('other'), 'profiles/learner')));
});

test('roster writes stay with the right person', async () => {
  await seed(async (adminDb) => {
    await setDoc(doc(adminDb, 'listings/class1'), { creatorId: 'master', title: 'Hindustani vocals' });
    await setDoc(doc(adminDb, 'profiles/learner'), { mcId: 'MC100245' });
    await setDoc(doc(adminDb, 'profiles/master'), { mcId: 'MC100001' });
  });
  const learner = db('learner');
  const master = db('master');
  const stranger = db('stranger');

  await assertFails(getDocs(collection(stranger, 'listings/class1/enrollments')));
  await assertSucceeds(setDoc(doc(learner, 'listings/class1/enrollments/MC100245'), {
    mcId: 'MC100245',
    userId: 'learner',
    userName: 'Anita',
    attendees: [{ id: 'asha', name: 'Asha', age: '9', phone: '', batchId: 'morning' }],
  }));
  await assertFails(setDoc(doc(learner, 'listings/class1/enrollments/MC100999'), {
    mcId: 'MC100999',
    userId: 'learner',
    userName: 'Anita',
    attendees: [{ id: 'x', name: 'X', age: '', phone: '', batchId: '' }],
  }));

  await assertSucceeds(setDoc(doc(learner, 'listings/class1/fees/MC100245_asha'), {
    mcId: 'MC100245',
    attendeeId: 'asha',
    amountPaid: 0,
    unitAmount: 800,
    feePeriod: 'month',
  }));
  await assertFails(updateDoc(doc(learner, 'listings/class1/fees/MC100245_asha'), { amountPaid: 800 }));
  await assertSucceeds(updateDoc(doc(learner, 'listings/class1/fees/MC100245_asha'), {
    utr: '123456789012',
    utrStatus: 'submitted',
    claimedAmount: 400,
  }));
  await assertSucceeds(updateDoc(doc(master, 'listings/class1/fees/MC100245_asha'), {
    amountPaid: 400,
    utrStatus: 'verified',
  }));

  await assertFails(setDoc(doc(learner, 'listings/class1/attendance/2026-11-15'), {
    date: '2026-11-15',
    marks: { 'MC100245:asha': 'present' },
  }));
  await assertSucceeds(setDoc(doc(master, 'listings/class1/attendance/2026-11-15'), {
    date: '2026-11-15',
    marks: { 'MC100245:asha': 'present' },
  }));
  await assertSucceeds(getDocs(collection(learner, 'listings/class1/attendance')));
  await assertFails(getDocs(collection(stranger, 'listings/class1/fees')));

  await assertSucceeds(updateDoc(doc(master, 'listings/class1/enrollments/MC100245'), {
    attendees: [{ id: 'asha', name: 'Asha', age: '9', phone: '', batchId: 'evening' }],
  }));
});

test('reviews are one per joined learner', async () => {
  await seed(async (adminDb) => {
    await setDoc(doc(adminDb, 'listings/class1'), { creatorId: 'master', title: 'Hindustani vocals' });
    await setDoc(doc(adminDb, 'profiles/learner'), { mcId: 'MC100245' });
    await setDoc(doc(adminDb, 'profiles/outsider'), { mcId: 'MC100300' });
    await setDoc(doc(adminDb, 'listings/class1/enrollments/MC100245'), {
      mcId: 'MC100245',
      userId: 'learner',
      userName: 'Anita',
      attendees: [],
    });
  });
  const review = {
    listingId: 'class1',
    listingTitle: 'Hindustani vocals',
    masterId: 'master',
    masterName: 'Meera',
    authorId: 'learner',
    authorName: 'Anita',
    mcId: 'MC100245',
    classRating: 5,
    masterRating: 4,
    text: 'Clear and kind.',
    createdAt: '2026-11-15',
  };
  await assertFails(setDoc(doc(db('outsider'), 'listings/class1/reviews/outsider'), {
    ...review,
    authorId: 'outsider',
  }));
  await assertSucceeds(setDoc(doc(db('learner'), 'listings/class1/reviews/learner'), review));
  await assertFails(setDoc(doc(db('learner'), 'listings/class1/reviews/someone-else'), review));
  await assertSucceeds(getDoc(doc(db(null), 'listings/class1/reviews/learner')));
  await assertSucceeds(setDoc(doc(db('learner'), 'profiles/master/receivedReviews/class1_learner'), review));
  await assertFails(getDoc(doc(db('learner'), 'profiles/master/receivedReviews/class1_learner')));
  await assertSucceeds(getDoc(doc(db('master'), 'profiles/master/receivedReviews/class1_learner')));
});

test('batches and announcements are written only by the master', async () => {
  await seed(async (adminDb) => {
    await setDoc(doc(adminDb, 'listings/class1'), { creatorId: 'master', title: 'Hindustani vocals' });
  });
  const batch = {
    name: 'Morning',
    days: ['Mon', 'Wed'],
    time: '07:00',
    capacity: 8,
    startDate: '2026-11-16',
    endDate: '2026-12-31',
  };
  await assertFails(setDoc(doc(db('learner'), 'listings/class1/batches/morning'), batch));
  await assertSucceeds(setDoc(doc(db('master'), 'listings/class1/batches/morning'), batch));
  await assertFails(setDoc(doc(db('learner'), 'listings/class1/announcements/a1'), {
    title: 'Holiday',
    body: 'No class on Friday.',
    batchId: '',
    authorId: 'learner',
    createdAt: '2026-11-15T00:00:00.000Z',
  }));
  await assertSucceeds(setDoc(doc(db('master'), 'listings/class1/announcements/a1'), {
    title: 'Holiday',
    body: 'No class on Friday.',
    batchId: '',
    authorId: 'master',
    createdAt: '2026-11-15T00:00:00.000Z',
  }));
  await assertSucceeds(getDoc(doc(db(null), 'listings/class1/announcements/a1')));
});

test('a learner records only their own interest and the master can read it', async () => {
  await seed(async (adminDb) => {
    await setDoc(doc(adminDb, 'listings/class1'), { creatorId: 'master', title: 'Tabla' });
    await setDoc(doc(adminDb, 'profiles/learner'), { mcId: 'MC100245' });
    await setDoc(doc(adminDb, 'listings_contact/class1'), {
      creatorId: 'master',
      contactNumber: '9845000000',
      masterName: 'Meera',
      masterEmail: 'meera@example.com',
      masterPhone: '9845000000',
      upiId: 'meera@oksbi',
    });
  });
  const interest = {
    userId: 'learner',
    listingId: 'class1',
    status: 'interested',
    listingTitle: 'Tabla',
    userName: 'Anita',
    userEmail: 'anita@example.com',
    mcId: 'MC100245',
    contactNumber: '9845011122',
    createdAt: '2026-11-15T03:30:00.000Z',
  };
  await assertFails(getDoc(doc(db(null), 'listings_contact/class1')));
  await assertFails(getDoc(doc(db('learner'), 'listings_contact/class1')));
  await assertFails(getDoc(doc(db('stranger'), 'listings/class1/interests/learner')));
  await assertFails(setDoc(doc(db('learner'), 'listings/class1/interests/stranger'), {
    ...interest,
    userId: 'stranger',
  }));
  await assertFails(setDoc(doc(db('learner'), 'listings/class1/interests/learner'), {
    ...interest,
    mcId: 'not-an-id',
  }));
  await assertSucceeds(setDoc(doc(db('learner'), 'listings/class1/interests/learner'), interest));
  await assertSucceeds(getDoc(doc(db('learner'), 'listings/class1/interests/learner')));
  await assertSucceeds(getDoc(doc(db('master'), 'listings/class1/interests/learner')));
  await assertSucceeds(getDocs(collection(db('master'), 'listings/class1/interests')));
  await assertFails(getDocs(collection(db('stranger'), 'listings/class1/interests')));
  await assertSucceeds(getDoc(doc(db('learner'), 'listings_contact/class1')));
  await assertFails(getDoc(doc(db('stranger'), 'listings_contact/class1')));
  await assertSucceeds(getDoc(doc(db('master'), 'listings_contact/class1')));
});

test('inbox and saved classes belong to the profile owner', async () => {
  const note = {
    title: 'Class reminder',
    body: 'Hindustani vocals starts tomorrow.',
    kind: 'class_reminder',
    read: false,
    createdAt: now(),
  };
  await assertSucceeds(setDoc(doc(db('learner'), 'profiles/learner/notifications/n1'), note));
  await assertFails(getDoc(doc(db('other'), 'profiles/learner/notifications/n1')));
  await assertFails(setDoc(doc(db('other'), 'profiles/learner/notifications/n2'), {
    ...note,
    kind: 'fee_due',
  }));
  await assertSucceeds(setDoc(doc(db('master'), 'profiles/learner/notifications/n3'), {
    ...note,
    kind: 'announcement',
    title: 'Bring the book',
    body: 'Page 12.',
  }));
  await assertSucceeds(setDoc(doc(db('learner'), 'profiles/learner/saved/class1'), {
    listingId: 'class1',
    title: 'Hindustani vocals',
    savedAt: now(),
  }));
  await assertFails(getDocs(collection(db('other'), 'profiles/learner/saved')));
});
