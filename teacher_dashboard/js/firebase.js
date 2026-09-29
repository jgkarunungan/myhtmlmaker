// Universal Teacher Dashboard - Firebase Web SDK Initialization
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-app.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-auth.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";

const FIREBASE_CONFIG = {
  apiKey: "", // Shared Web API Key
  authDomain: "online-classes-database-70d53.firebaseapp.com",
  projectId: "online-classes-database-70d53",
  storageBucket: "online-classes-database-70d53.firebasestorage.app",
  messagingSenderId: "",
  appId: ""
};

export const app = initializeApp(FIREBASE_CONFIG);
export const auth = getAuth(app);
export const db = getFirestore(app);
