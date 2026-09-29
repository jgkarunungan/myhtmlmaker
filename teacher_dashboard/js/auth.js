// Universal Teacher Dashboard - Authentication & Authorization Controller
import { auth, db } from "./firebase.js";
import { signInWithEmailAndPassword, signOut, onAuthStateChanged } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-auth.js";
import { doc, getDoc } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";
import { loadTeacherModules } from "./dashboard.js";

let currentTeacherUser = null;

document.addEventListener('DOMContentLoaded', () => {
  const loginForm = document.getElementById('login-form');
  const btnSignOut = document.getElementById('btn-signout');

  if (loginForm) {
    loginForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = document.getElementById('email').value.trim();
      const password = document.getElementById('password').value.trim();
      const authErrorMsg = document.getElementById('auth-error-msg');

      if (authErrorMsg) authErrorMsg.style.display = 'none';

      try {
        const cred = await signInWithEmailAndPassword(auth, email, password);
        await verifyAndAuthorizeTeacher(cred.user);
      } catch (err) {
        console.error('Login error:', err);
        if (authErrorMsg) {
          authErrorMsg.textContent = err.message || 'Authentication failed. Please check credentials.';
          authErrorMsg.style.display = 'block';
        }
      }
    });
  }

  if (btnSignOut) {
    btnSignOut.addEventListener('click', async () => {
      await signOut(auth);
      currentTeacherUser = null;
      showLoginView();
    });
  }

  // Observe Firebase Auth State
  onAuthStateChanged(auth, async (user) => {
    if (user) {
      await verifyAndAuthorizeTeacher(user);
    } else {
      currentTeacherUser = null;
      showLoginView();
    }
  });
});

async function verifyAndAuthorizeTeacher(user) {
  const authErrorMsg = document.getElementById('auth-error-msg');
  try {
    const teacherDocRef = doc(db, 'teachers', user.uid);
    const snap = await getDoc(teacherDocRef);

    if (snap.exists()) {
      const data = snap.data();
      if (data.role === 'teacher' && data.active === true) {
        currentTeacherUser = user;
        showDashboardView(user);
        await loadTeacherModules(user.uid);
        return;
      }
    }

    // Account exists in Auth but is NOT authorized as a active teacher
    await signOut(auth);
    currentTeacherUser = null;
    if (authErrorMsg) {
      authErrorMsg.textContent = 'Your Firebase account is authenticated but is not authorized as a teacher.';
      authErrorMsg.style.display = 'block';
    }
    showLoginView();
  } catch (err) {
    console.error('Authorization check error:', err);
    await signOut(auth);
    currentTeacherUser = null;
    if (authErrorMsg) {
      authErrorMsg.textContent = 'Authorization check failed: ' + err.message;
      authErrorMsg.style.display = 'block';
    }
    showLoginView();
  }
}

function showLoginView() {
  const loginScreen = document.getElementById('login-screen');
  const dashboardApp = document.getElementById('dashboard-app');
  if (loginScreen) loginScreen.style.display = 'flex';
  if (dashboardApp) dashboardApp.style.display = 'none';
}

function showDashboardView(user) {
  const loginScreen = document.getElementById('login-screen');
  const dashboardApp = document.getElementById('dashboard-app');
  const userEmailDisplay = document.getElementById('user-email-display');

  if (loginScreen) loginScreen.style.display = 'none';
  if (dashboardApp) dashboardApp.style.display = 'block';
  if (userEmailDisplay) userEmailDisplay.textContent = user.email;
}

export function getCurrentTeacher() {
  return currentTeacherUser;
}
