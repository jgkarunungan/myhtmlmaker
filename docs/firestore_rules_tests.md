# Firestore Security Rules Test Cases & Specifications

These test specifications document the security rules defined in `firestore.rules`.

## Collections Covered
1. `teachers/{uid}`
2. `modules/{moduleId}`
3. `modules/{moduleId}/activities/{activityId}`
4. `modules/{moduleId}/submissions/{studentUid}`

---

## Allowed Operations (ALLOW)

1. **ALLOW: Authorized Teacher Creates Own Module**
   - **Condition**: User is active teacher (`isTeacher()` & `active == true`), `request.resource.data.teacherUid == request.auth.uid`, and `request.resource.data.moduleId == moduleId`.
   - **Result**: Module created at `modules/mod_1234`.

2. **ALLOW: Authorized Teacher Updates Own Module**
   - **Condition**: User is active teacher owning the module (`resource.data.teacherUid == request.auth.uid`), preserving `teacherUid` and `moduleId`.
   - **Result**: Module metadata updated.

3. **ALLOW: Authorized Teacher Reads Own Module & Submissions**
   - **Condition**: Active teacher reads `modules/mod_1234` or lists `modules/mod_1234/submissions`.
   - **Result**: Read/list succeeds.

4. **ALLOW: Teacher Writes Grading Fields**
   - **Condition**: Owning teacher updates `modules/mod_1234/submissions/student_1` modifying `teacherScore`, `verifiedAutoScore`, `rubricScores`, `teacherFeedback`, `gradingStatus`, `gradedAt`, `gradedBy`, `finalScore` without altering `student` or `responses`.
   - **Result**: Update succeeds.

5. **ALLOW: Anonymous Student Creates Own Submission for Published Module**
   - **Condition**: Student is authenticated, `request.auth.uid == studentUid`, `parent module exists`, and `parent.status == "published"`.
   - **Result**: Submission created.

---

## Denied Operations (DENY)

6. **DENY: Student Submission for Draft Module**
   - **Condition**: Student attempts to create submission at `modules/mod_1234/submissions/student_1` where `modules/mod_1234.status == "draft"`.
   - **Result**: Write denied.

7. **DENY: Student Creates Module Registry**
   - **Condition**: Anonymous student attempts write to `modules/mod_5678`.
   - **Result**: Write denied (`isActiveTeacher()` required).

8. **DENY: Student Reads Activity Grading Metadata**
   - **Condition**: Anonymous student attempts read on `modules/mod_1234/activities/act_1`.
   - **Result**: Read denied (`ownsModule()` or active teacher required).

9. **DENY: Student Reads Classmate Submission**
   - **Condition**: Student `user_A` attempts GET on `modules/mod_1234/submissions/user_B`.
   - **Result**: Read denied.

10. **DENY: Teacher A Reads Teacher B Module Submissions**
    - **Condition**: Teacher `teacher_A` attempts GET on `modules/mod_owned_by_B/submissions/student_1`.
    - **Result**: Read denied (`ownsModule()` required).

11. **DENY: Teacher Changes Module teacherUid**
    - **Condition**: Teacher attempts update altering `teacherUid`.
    - **Result**: Update denied (`request.resource.data.teacherUid == resource.data.teacherUid`).

12. **DENY: Student Changes teacherScore**
    - **Condition**: Student attempts update containing `teacherScore`.
    - **Result**: Update denied.

13. **DENY: Teacher Overwrites Student Responses While Grading**
    - **Condition**: Teacher attempts update on submission containing `responses` field change.
    - **Result**: Update denied (`affectedKeys().hasAny(['student', 'responses'])` blocked).

14. **DENY: Ordinary Authenticated User Without Teacher Authorization Accesses Dashboard Data**
    - **Condition**: Authenticated user missing `teachers/{uid}` or `active == false` attempts write to `modules/{moduleId}`.
    - **Result**: Denied (`isActiveTeacher()` required).
