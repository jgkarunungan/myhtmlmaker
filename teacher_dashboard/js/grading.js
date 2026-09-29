// Universal Teacher Dashboard - Student Detailed Grading & Feedback Controller
import { db } from "./firebase.js";
import { collection, getDocs, doc, updateDoc, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";
import { getCurrentTeacher } from "./auth.js";
import { loadSubmissionsForModule } from "./dashboard.js";

let activeModuleActivities = [];
let currentSubmission = null;
let currentSubmissionsList = [];
let currentSubmissionIndex = 0;
let currentModuleId = null;

export async function openGradingModal(moduleId, submission, submissionsList, index) {
  currentModuleId = moduleId;
  currentSubmission = submission;
  currentSubmissionsList = submissionsList;
  currentSubmissionIndex = index;

  const modal = document.getElementById('grading-modal');
  if (!modal) return;

  modal.style.display = 'flex';

  // Load authoritative activity metadata
  await loadActivityMetadata(moduleId);

  // Render student info header
  renderStudentInfo(submission);

  // Calculate & render activities + rubrics
  renderGradingBody(submission);

  // Setup navigation & save buttons
  setupGradingActionListeners();
}

async function loadActivityMetadata(moduleId) {
  activeModuleActivities = [];
  try {
    const actRef = collection(db, 'modules', moduleId, 'activities');
    const snap = await getDocs(actRef);
    snap.forEach((docSnap) => {
      activeModuleActivities.push(docSnap.data());
    });
    // Sort activities by sourceOrder
    activeModuleActivities.sort((a, b) => (a.sourceOrder || 0) - (b.sourceOrder || 0));
  } catch (err) {
    console.error('Failed to load activity metadata:', err);
  }
}

function renderStudentInfo(submission) {
  const student = submission.student || {};
  const fullName = `${student.surname || ''}, ${student.firstName || ''} ${student.middleName || ''}`.trim() || 'Unknown Student';

  document.getElementById('grade-student-name').textContent = fullName;
  document.getElementById('grade-student-meta').textContent =
    `Grade: ${student.gradeLevel || '-'} | Section: ${student.section || '-'} | LRN: ${student.lrn || 'None'}`;

  // Reset feedback
  const feedbackInput = document.getElementById('teacher-feedback-input');
  if (feedbackInput) {
    feedbackInput.value = submission.teacherFeedback || '';
  }
}

function renderGradingBody(submission) {
  const container = document.getElementById('grading-activities-container');
  if (!container) return;

  container.innerHTML = '';

  const responses = submission.responses || {};
  const rubricScores = submission.rubricScores || {};

  let verifiedAutoEarned = 0;
  let verifiedAutoPossible = 0;
  let hasDiscrepancy = false;

  activeModuleActivities.forEach((act) => {
    const actCard = document.createElement('div');
    actCard.className = 'card grading-activity-card';

    const actResponses = responses[act.activityId] || {};
    let actBodyHtml = `<h3>${act.title || 'Activity'} <span class="badge badge-pts">${act.points || 0} pts</span></h3>`;
    if (act.instructions) {
      actBodyHtml += `<p class="instructions">${act.instructions}</p>`;
    }

    // Objective / Automatic questions check
    if (act.gradingMode === 'automatic' && act.questions && act.questions.length > 0) {
      actBodyHtml += `<div class="auto-questions-list">`;
      act.questions.forEach((q, qI) => {
        const studentAns = (actResponses[q.questionId] || '').toString().trim();
        const expectedAns = (q.correctAnswer || '').toString().trim();
        const pts = q.points || 1;

        if (q.answerStatus === 'provided' || q.answerStatus === 'inferredHighConfidence') {
          verifiedAutoPossible += pts;
          const isCorrect = studentAns.toLowerCase() === expectedAns.toLowerCase();
          if (isCorrect) verifiedAutoEarned += pts;

          actBodyHtml += `
            <div class="q-review-item ${isCorrect ? 'correct' : 'incorrect'}">
              <p><strong>Q${qI + 1}:</strong> ${q.prompt || ''}</p>
              <p>Student Answer: <code>${studentAns || '(No answer)'}</code></p>
              <p>Correct Answer: <code>${expectedAns}</code> (${q.answerStatus}) [${isCorrect ? '+' + pts : '0'} pts]</p>
            </div>
          `;
        } else {
          actBodyHtml += `
            <div class="q-review-item pending">
              <p><strong>Q${qI + 1}:</strong> ${q.prompt || ''}</p>
              <p>Student Answer: <code>${studentAns || '(No answer)'}</code></p>
              <p><em>Answer missing in lesson text — skipped from automatic scoring.</em></p>
            </div>
          `;
        }
      });
      actBodyHtml += `</div>`;
    } else {
      // Subjective activity
      actBodyHtml += `<div class="subjective-responses-list">`;
      if (act.questions && act.questions.length > 0) {
        act.questions.forEach((q, qI) => {
          const studentAns = actResponses[q.questionId] || '(No response)';
          actBodyHtml += `
            <div class="response-box">
              <p><strong>Prompt ${qI + 1}:</strong> ${q.prompt || ''}</p>
              <blockquote class="student-ans-text">${studentAns}</blockquote>
            </div>
          `;
        });
      } else {
        actBodyHtml += `<blockquote class="student-ans-text">${JSON.stringify(actResponses)}</blockquote>`;
      }
      actBodyHtml += `</div>`;

      // Render Rubric Criteria Scoring Inputs
      if (act.rubric && act.rubric.criteria && act.rubric.criteria.length > 0) {
        const isAiSuggested = act.rubric.type === 'aiSuggested';
        actBodyHtml += `
          <div class="rubric-scoring-box">
            <h4>Evaluation Rubric ${isAiSuggested ? '<span class="badge badge-ai">AI-suggested rubric</span>' : ''}</h4>
            <table class="rubric-input-table">
              <thead><tr><th>Criteria Description</th><th>Max Pts</th><th>Score</th></tr></thead>
              <tbody>
        `;

        const actRubricScores = rubricScores[act.activityId] || {};

        act.rubric.criteria.forEach((crit) => {
          const savedScore = actRubricScores[crit.criterionId] !== undefined ? actRubricScores[crit.criterionId] : 0;
          actBodyHtml += `
            <tr>
              <td>${crit.description || 'Criterion'}</td>
              <td>${crit.maxPoints || 0}</td>
              <td>
                <input type="number" class="rubric-score-input"
                       data-act-id="${act.activityId}"
                       data-crit-id="${crit.criterionId}"
                       data-max-pts="${crit.maxPoints || 0}"
                       min="0" max="${crit.maxPoints || 0}"
                       value="${savedScore}">
              </td>
            </tr>
          `;
        });

        actBodyHtml += `</tbody></table></div>`;
      }
    }

    actCard.innerHTML = actBodyHtml;
    container.appendChild(actCard);
  });

  // Check discrepancy with clientAutoScore
  if (submission.clientAutoScore && submission.clientAutoScore.earned !== undefined) {
    if (submission.clientAutoScore.earned !== verifiedAutoEarned) {
      hasDiscrepancy = true;
    }
  }

  const discrepancyWarning = document.getElementById('discrepancy-warning');
  if (discrepancyWarning) {
    if (hasDiscrepancy) {
      discrepancyWarning.style.display = 'block';
      discrepancyWarning.textContent = `Warning: Client auto-score (${submission.clientAutoScore.earned}/${submission.clientAutoScore.possible}) differs from verified score (${verifiedAutoEarned}/${verifiedAutoPossible}). Authoritative verified score will be saved.`;
    } else {
      discrepancyWarning.style.display = 'none';
    }
  }

  updateLiveScoreCalculation();

  // Attach inputs listener for live score updating
  document.querySelectorAll('.rubric-score-input').forEach((input) => {
    input.oninput = () => updateLiveScoreCalculation();
  });
}

function updateLiveScoreCalculation() {
  let subjectiveEarned = 0;
  let subjectivePossible = 0;

  document.querySelectorAll('.rubric-score-input').forEach((input) => {
    const maxPts = parseFloat(input.getAttribute('data-max-pts')) || 0;
    let val = parseFloat(input.value) || 0;

    if (val < 0) val = 0;
    if (val > maxPts) val = maxPts;
    input.value = val;

    subjectiveEarned += val;
    subjectivePossible += maxPts;
  });

  // Calculate verified auto score
  let autoEarned = 0;
  let autoPossible = 0;

  activeModuleActivities.forEach((act) => {
    if (act.gradingMode === 'automatic' && act.questions) {
      const actResponses = (currentSubmission?.responses || {})[act.activityId] || {};
      act.questions.forEach((q) => {
        if (q.answerStatus === 'provided' || q.answerStatus === 'inferredHighConfidence') {
          const pts = q.points || 1;
          autoPossible += pts;
          const studentAns = (actResponses[q.questionId] || '').toString().trim().toLowerCase();
          const expectedAns = (q.correctAnswer || '').toString().trim().toLowerCase();
          if (studentAns !== '' && studentAns === expectedAns) {
            autoEarned += pts;
          }
        }
      });
    }
  });

  const finalEarned = autoEarned + subjectiveEarned;
  const finalPossible = autoPossible + subjectivePossible;

  const scoreDisplay = document.getElementById('live-score-display');
  if (scoreDisplay) {
    scoreDisplay.textContent = `Final Score: ${finalEarned} / ${finalPossible} pts (Auto: ${autoEarned}/${autoPossible} + Subjective: ${subjectiveEarned}/${subjectivePossible})`;
  }
}

function setupGradingActionListeners() {
  const btnClose = document.getElementById('btn-close-modal');
  const btnSave = document.getElementById('btn-save-grade');
  const btnPrev = document.getElementById('btn-prev-student');
  const btnNext = document.getElementById('btn-next-student');

  if (btnClose) {
    btnClose.onclick = () => {
      document.getElementById('grading-modal').style.display = 'none';
    };
  }

  if (btnPrev) {
    btnPrev.disabled = currentSubmissionIndex <= 0;
    btnPrev.onclick = () => {
      if (currentSubmissionIndex > 0) {
        openGradingModal(currentModuleId, currentSubmissionsList[currentSubmissionIndex - 1], currentSubmissionsList, currentSubmissionIndex - 1);
      }
    };
  }

  if (btnNext) {
    btnNext.disabled = currentSubmissionIndex >= currentSubmissionsList.length - 1;
    btnNext.onclick = () => {
      if (currentSubmissionIndex < currentSubmissionsList.length - 1) {
        openGradingModal(currentModuleId, currentSubmissionsList[currentSubmissionIndex + 1], currentSubmissionsList, currentSubmissionIndex + 1);
      }
    };
  }

  if (btnSave) {
    btnSave.onclick = async () => {
      await saveStudentGrade();
    };
  }
}

async function saveStudentGrade() {
  const teacher = getCurrentTeacher();
  if (!teacher || !currentSubmission) return;

  const btnSave = document.getElementById('btn-save-grade');
  if (btnSave) btnSave.disabled = true;

  try {
    const feedbackText = (document.getElementById('teacher-feedback-input')?.value || '').trim();

    // Gather rubric scores
    const rubricScoresMap = {};
    let subjectiveEarned = 0;
    let subjectivePossible = 0;

    document.querySelectorAll('.rubric-score-input').forEach((input) => {
      const actId = input.getAttribute('data-act-id');
      const critId = input.getAttribute('data-crit-id');
      const maxPts = parseFloat(input.getAttribute('data-max-pts')) || 0;
      const score = parseFloat(input.value) || 0;

      if (!rubricScoresMap[actId]) rubricScoresMap[actId] = {};
      rubricScoresMap[actId][critId] = score;

      subjectiveEarned += score;
      subjectivePossible += maxPts;
    });

    // Calculate verified auto score
    let autoEarned = 0;
    let autoPossible = 0;

    activeModuleActivities.forEach((act) => {
      if (act.gradingMode === 'automatic' && act.questions) {
        const actResponses = (currentSubmission.responses || {})[act.activityId] || {};
        act.questions.forEach((q) => {
          if (q.answerStatus === 'provided' || q.answerStatus === 'inferredHighConfidence') {
            const pts = q.points || 1;
            autoPossible += pts;
            const studentAns = (actResponses[q.questionId] || '').toString().trim().toLowerCase();
            const expectedAns = (q.correctAnswer || '').toString().trim().toLowerCase();
            if (studentAns !== '' && studentAns === expectedAns) {
              autoEarned += pts;
            }
          }
        });
      }
    });

    const finalEarned = autoEarned + subjectiveEarned;
    const finalPossible = autoPossible + subjectivePossible;

    const subDocRef = doc(db, 'modules', currentModuleId, 'submissions', currentSubmission._submissionUid);

    const updateData = {
      verifiedAutoScore: { earned: autoEarned, possible: autoPossible },
      teacherScore: { earned: subjectiveEarned, possible: subjectivePossible },
      rubricScores: rubricScoresMap,
      teacherFeedback: feedbackText,
      gradingStatus: 'graded',
      gradedAt: serverTimestamp(),
      gradedBy: teacher.uid,
      finalScore: { earned: finalEarned, possible: finalPossible }
    };

    await updateDoc(subDocRef, updateData);

    if (btnSave) btnSave.disabled = false;
    alert('Grade and feedback saved successfully!');

    // Refresh dashboard list
    await loadSubmissionsForModule(currentModuleId);
  } catch (err) {
    console.error('Failed to save grade:', err);
    if (btnSave) btnSave.disabled = false;
    alert('Failed to save grade: ' + err.message);
  }
}
