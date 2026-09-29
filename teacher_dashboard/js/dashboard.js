// Universal Teacher Dashboard - Module List & Submission Management
import { db } from "./firebase.js";
import { collection, query, where, getDocs } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";
import { openGradingModal } from "./grading.js";

let loadedModulesMap = {};
let currentSelectedModuleId = null;
let currentModuleSubmissions = [];

export async function loadTeacherModules(teacherUid) {
  const moduleSelect = document.getElementById('module-select');
  const emptyState = document.getElementById('no-modules-state');
  const moduleDetailsContainer = document.getElementById('module-details-container');

  if (!moduleSelect) return;

  moduleSelect.innerHTML = '<option value="">-- Select Registered Module --</option>';
  loadedModulesMap = {};

  try {
    const modulesRef = collection(db, 'modules');
    const q = query(modulesRef, where('teacherUid', '==', teacherUid));
    const snap = await getDocs(q);

    if (snap.empty) {
      if (emptyState) emptyState.style.display = 'block';
      if (moduleDetailsContainer) moduleDetailsContainer.style.display = 'none';
      return;
    }

    if (emptyState) emptyState.style.display = 'none';

    snap.forEach((docSnap) => {
      const data = docSnap.data();
      loadedModulesMap[docSnap.id] = data;

      const opt = document.createElement('option');
      opt.value = docSnap.id;
      opt.textContent = `${data.title} (${data.subject} - ${data.gradeLevel}) [${data.status || 'draft'}]`;
      moduleSelect.appendChild(opt);
    });

    // Auto-select first module if available
    const firstId = Object.keys(loadedModulesMap)[0];
    if (firstId) {
      moduleSelect.value = firstId;
      await handleModuleSelected(firstId);
    }

    moduleSelect.onchange = async (e) => {
      const selectedId = e.target.value;
      if (selectedId) {
        await handleModuleSelected(selectedId);
      } else {
        if (moduleDetailsContainer) moduleDetailsContainer.style.display = 'none';
      }
    };
  } catch (err) {
    console.error('Failed to load modules:', err);
  }
}

export async function handleModuleSelected(moduleId) {
  currentSelectedModuleId = moduleId;
  const moduleData = loadedModulesMap[moduleId];
  const moduleDetailsContainer = document.getElementById('module-details-container');

  if (!moduleData || !moduleDetailsContainer) return;

  moduleDetailsContainer.style.display = 'block';

  // Render module header details
  document.getElementById('display-module-title').textContent = moduleData.title || 'Untitled';
  document.getElementById('display-module-meta').textContent =
    `Subject: ${moduleData.subject || 'General'} | Grade: ${moduleData.gradeLevel || 'Grade 11'} | Status: ${(moduleData.status || 'draft').toUpperCase()} | Total Points: ${moduleData.totalPoints || 0}`;

  // Load submissions ONLY for the selected module
  await loadSubmissionsForModule(moduleId);
}

export async function loadSubmissionsForModule(moduleId) {
  currentModuleSubmissions = [];
  try {
    const subRef = collection(db, 'modules', moduleId, 'submissions');
    const snap = await getDocs(subRef);

    snap.forEach((docSnap) => {
      const data = docSnap.data();
      data._submissionUid = docSnap.id;
      currentModuleSubmissions.push(data);
    });

    // Sort students by Surname, First Name, Middle Name
    sortSubmissionsByStudentName(currentModuleSubmissions);

    // Compute and display summary stats
    updateModuleSummaryStats(currentModuleSubmissions);

    // Populate filter dropdowns (Grade, Section)
    populateFilterDropdowns(currentModuleSubmissions);

    // Render table
    renderSubmissionsTable();

    // Setup filter event listeners
    setupFilterListeners();
  } catch (err) {
    console.error('Failed to load submissions for module:', err);
  }
}

export function sortSubmissionsByStudentName(submissionsList) {
  submissionsList.sort((a, b) => {
    const surnameA = (a.student?.surname || '').toLowerCase();
    const surnameB = (b.student?.surname || '').toLowerCase();
    if (surnameA !== surnameB) return surnameA.localeCompare(surnameB);

    const firstA = (a.student?.firstName || '').toLowerCase();
    const firstB = (b.student?.firstName || '').toLowerCase();
    if (firstA !== firstB) return firstA.localeCompare(firstB);

    const midA = (a.student?.middleName || '').toLowerCase();
    const midB = (b.student?.middleName || '').toLowerCase();
    return midA.localeCompare(midB);
  });
}

function updateModuleSummaryStats(submissions) {
  let totalStudents = submissions.length;
  let inProgressCount = 0;
  let submittedCount = 0;
  let gradedCount = 0;
  let pendingCount = 0;
  let totalScoreSum = 0;
  let gradedScoreCount = 0;

  submissions.forEach((sub) => {
    if (sub.status === 'draft') {
      inProgressCount++;
    } else if (sub.status === 'submitted') {
      submittedCount++;
      if (sub.gradingStatus === 'graded') {
        gradedCount++;
        if (sub.finalScore?.earned !== undefined) {
          totalScoreSum += sub.finalScore.earned;
          gradedScoreCount++;
        }
      } else {
        pendingCount++;
      }
    }
  });

  const avgScore = gradedScoreCount > 0 ? (totalScoreSum / gradedScoreCount).toFixed(1) : 'N/A';

  document.getElementById('stat-total-students').textContent = totalStudents;
  document.getElementById('stat-submitted').textContent = submittedCount;
  document.getElementById('stat-graded').textContent = gradedCount;
  document.getElementById('stat-pending').textContent = pendingCount;
  document.getElementById('stat-avg-score').textContent = avgScore;
}

function populateFilterDropdowns(submissions) {
  const gradeFilter = document.getElementById('filter-grade');
  const sectionFilter = document.getElementById('filter-section');

  const grades = new Set();
  const sections = new Set();

  submissions.forEach((sub) => {
    if (sub.student?.gradeLevel) grades.add(sub.student.gradeLevel);
    if (sub.student?.section) sections.add(sub.student.section);
  });

  if (gradeFilter) {
    gradeFilter.innerHTML = '<option value="all">All Grades</option>';
    grades.forEach((g) => {
      const opt = document.createElement('option');
      opt.value = g;
      opt.textContent = g;
      gradeFilter.appendChild(opt);
    });
  }

  if (sectionFilter) {
    sectionFilter.innerHTML = '<option value="all">All Sections</option>';
    sections.forEach((s) => {
      const opt = document.createElement('option');
      opt.value = s;
      opt.textContent = s;
      sectionFilter.appendChild(opt);
    });
  }
}

function setupFilterListeners() {
  const gradeFilter = document.getElementById('filter-grade');
  const sectionFilter = document.getElementById('filter-section');
  const statusFilter = document.getElementById('filter-status');
  const searchInput = document.getElementById('filter-search');

  const handler = () => renderSubmissionsTable();

  if (gradeFilter) gradeFilter.onchange = handler;
  if (sectionFilter) sectionFilter.onchange = handler;
  if (statusFilter) statusFilter.onchange = handler;
  if (searchInput) searchInput.oninput = handler;
}

export function renderSubmissionsTable() {
  const tableBody = document.getElementById('submissions-table-body');
  const gradeFilter = document.getElementById('filter-grade')?.value || 'all';
  const sectionFilter = document.getElementById('filter-section')?.value || 'all';
  const statusFilter = document.getElementById('filter-status')?.value || 'all';
  const searchText = (document.getElementById('filter-search')?.value || '').toLowerCase().trim();

  if (!tableBody) return;

  tableBody.innerHTML = '';

  const filtered = currentModuleSubmissions.filter((sub) => {
    if (gradeFilter !== 'all' && sub.student?.gradeLevel !== gradeFilter) return false;
    if (sectionFilter !== 'all' && sub.student?.section !== sectionFilter) return false;
    if (statusFilter !== 'all') {
      if (statusFilter === 'draft' && sub.status !== 'draft') return false;
      if (statusFilter === 'submitted' && sub.status !== 'submitted') return false;
      if (statusFilter === 'pending' && (sub.status !== 'submitted' || sub.gradingStatus === 'graded')) return false;
      if (statusFilter === 'graded' && sub.gradingStatus !== 'graded') return false;
    }
    if (searchText) {
      const fullName = `${sub.student?.firstName || ''} ${sub.student?.middleName || ''} ${sub.student?.surname || ''}`.toLowerCase();
      if (!fullName.includes(searchText)) return false;
    }
    return true;
  });

  if (filtered.length === 0) {
    tableBody.innerHTML = '<tr><td colspan="9" style="text-align:center; padding: 2rem; color: #64748B;">No matching student submissions found.</td></tr>';
    return;
  }

  filtered.forEach((sub, index) => {
    const tr = document.createElement('tr');

    const fullName = `${sub.student?.surname || ''}, ${sub.student?.firstName || ''} ${sub.student?.middleName || ''}`.trim() || 'Unknown Student';
    const grade = sub.student?.gradeLevel || '-';
    const section = sub.student?.section || '-';
    const status = sub.status || 'draft';
    const autoScore = sub.clientAutoScore ? `${sub.clientAutoScore.earned}/${sub.clientAutoScore.possible}` : '-';
    const teacherScore = sub.teacherScore ? `${sub.teacherScore.earned}/${sub.teacherScore.possible}` : '-';
    const finalScore = sub.finalScore ? `${sub.finalScore.earned}/${sub.finalScore.possible}` : (sub.gradingStatus === 'graded' ? 'Graded' : 'Pending');
    const gradingStatus = sub.gradingStatus === 'graded' ? 'Graded' : (status === 'submitted' ? 'Pending Grading' : 'In Progress');

    let submittedAtText = '-';
    if (sub.submittedAt && sub.submittedAt.seconds) {
      submittedAtText = new Date(sub.submittedAt.seconds * 1000).toLocaleString();
    }

    tr.innerHTML = `
      <td><strong>${fullName}</strong></td>
      <td>${grade}</td>
      <td>${section}</td>
      <td><span class="badge status-${status}">${status.toUpperCase()}</span></td>
      <td>${autoScore}</td>
      <td>${teacherScore}</td>
      <td><strong>${finalScore}</strong></td>
      <td><span class="badge status-${gradingStatus.toLowerCase().replace(' ', '-')}">${gradingStatus}</span></td>
      <td>
        <button type="button" class="btn btn-sm btn-primary btn-grade-student" data-index="${index}">Review / Grade</button>
      </td>
    `;

    tableBody.appendChild(tr);
  });

  // Attach click listeners to Grade buttons
  document.querySelectorAll('.btn-grade-student').forEach((btn) => {
    btn.onclick = () => {
      const idx = parseInt(btn.getAttribute('data-index'));
      const sub = filtered[idx];
      openGradingModal(currentSelectedModuleId, sub, filtered, idx);
    };
  });
}
