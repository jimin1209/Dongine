class FirestorePaths {
  // Users
  static const String users = 'users';
  static String user(String uid) => 'users/$uid';

  // Families
  static const String families = 'families';
  static String family(String familyId) => 'families/$familyId';
  static String familyMembers(String familyId) =>
      'families/$familyId/members';
  static String familyMember(String familyId, String uid) =>
      'families/$familyId/members/$uid';

  // Chat
  static String messages(String familyId) =>
      'families/$familyId/messages';

  // Location
  static String locations(String familyId) =>
      'families/$familyId/locations';
  static String memberLocation(String familyId, String uid) =>
      'families/$familyId/locations/$uid';

  // Files
  static String files(String familyId) =>
      'families/$familyId/files';

  // Calendar Events
  static String events(String familyId) =>
      'families/$familyId/events';

  // TODOs
  static String todos(String familyId) =>
      'families/$familyId/todos';

  // Cart (장보기)
  static String cartItems(String familyId) =>
      'families/$familyId/cart';

  // Expenses (가계부)
  static String expenses(String familyId) =>
      'families/$familyId/expenses';

  // Albums
  static String albums(String familyId) =>
      'families/$familyId/albums';
  static String album(String familyId, String albumId) =>
      'families/$familyId/albums/$albumId';
  static String albumPhotos(String familyId, String albumId) =>
      'families/$familyId/albums/$albumId/photos';

  // Invitations
  static const String invitations = 'invitations';
}
