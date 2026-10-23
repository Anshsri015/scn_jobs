/// Mirrors `UserRole`'s pattern (`user.dart`) — an enum plus an
/// explicit string-mapping function, rather than trusting Dart's
/// `enum.byName` to match the backend's exact casing/spelling.
///
/// ✅ CONFIRMED against the post-revamp Applications API doc
/// (Section 5 / 6): the application lifecycle is now just two
/// terminal outcomes.
/// - `POST /applications` always starts an application at `applied`.
/// - `PATCH /applications/:id/status` (recruiter-only) only ever sets
///   `accepted` or `rejected`.
/// - There is NO `shortlisted` / `interview_scheduled` / `hired`
///   anymore — those statuses (and the DB columns behind them) were
///   removed in the revamp. Deleted here too, not kept as dead cases,
///   so no switch anywhere can silently handle a status that will
///   never arrive again.
/// - Once `accepted` or `rejected`, the application is terminal — no
///   further status change is allowed from either state.
/// - There is NO `withdrawn` status either. Withdrawing is
///   `DELETE /applications/:id` — the application is removed
///   server-side, not transitioned to a terminal status. The client
///   reflects this by dropping the item from the list on a successful
///   withdraw (see `ApplicationsController.withdraw`), not by
///   rendering a "withdrawn" badge.
enum ApplicationStatus {
  applied,
  accepted,
  rejected,
}

/// ⚠️ If the backend ever adds a status this doesn't recognize, this
/// throws rather than silently mis-categorizing it — same defensive
/// choice as the pre-existing version of this file.
ApplicationStatus applicationStatusFromString(String value) {
  switch (value) {
    case 'applied':
      return ApplicationStatus.applied;
    case 'accepted':
      return ApplicationStatus.accepted;
    case 'rejected':
      return ApplicationStatus.rejected;
    default:
      throw ArgumentError('Unknown application status: $value');
  }
}
