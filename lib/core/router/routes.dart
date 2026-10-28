abstract final class AppRoutes {
  // Outside the signed-in shell
  static const splash = '/splash';
  static const signIn = '/sign-in'; // select society
  static const signInRole = '/sign-in/role';
  static const signInPhone = '/sign-in/phone';
  static const signInOtp = '/sign-in/otp';

  // Bottom-nav tabs (one shell branch each)
  static const home = '/home';
  static const tower = '/tower';
  static const maintenance = '/maintenance';
  static const community = '/community';
  static const profile = '/profile';

  // Full-screen pages pushed over the shell
  static const notifications = '/notifications';
  static const events = '/events';
  static const facilityBookings = '/facility-bookings';
  static const help = '/help';
  static const about = '/about';

  // Tower tab pages (keep the bottom nav)
  static const towerVisitors = '/tower/visitors';
  static const towerNotices = '/tower/notices';
  static const towerNeighbours = '/tower/neighbours';
  static const towerFacilities = '/tower/facilities';
  static String bookFacility(String facilityId) => '/tower/facilities/$facilityId/book';
  static const towerComplaints = '/tower/complaints';
  static const postComplaint = '/tower/complaints/new';

  // Maintenance tab pages
  static const payDues = '/maintenance/pay'; // owners and tenants
  static String payDue(String dueId) => '$payDues/$dueId';
  static String receipt(String paymentId) => '/maintenance/receipts/$paymentId';
  static const paymentHistory = '/maintenance/history';

  // Community tab pages
  static const communityPolls = '/community/polls';
  static String communityClub(String id) => '/community/clubs/$id';

  // Profile tab pages
  static const household = '/profile/household'; // owners and tenants
  static const services = '/profile/services';
  static String serviceCategory(String category) => '$services/${Uri.encodeComponent(category)}';
  static const paymentSettings = '/profile/payment-settings';
  static const languageSettings = '/profile/language';
  static const notificationSettings = '/profile/notifications';
  static const themeSettings = '/profile/theme';
  static const account = '/profile/account';
  static const editProfile = '/profile/edit';
  static const leaseInfo = '/profile/lease'; // tenants: owner contact + lease

  // Role-restricted sections
  static const towerManage = '/tower/manage'; // admin: notice + facility forms
  static const noticeForm = '/tower/manage/notice';
  static const facilityForm = '/tower/manage/facility';
  static const maintenanceConfig = '/maintenance/configure';
  static const defaulters = '/maintenance/defaulters';
  static const societyBills = '/maintenance/bills';
  static const communityManage = '/community/manage'; // admin: poll, club and announcement forms
  static const pollForm = '/community/manage/poll';
  static const communityForm = '/community/manage/club';
  static String editCommunity(String id) => '$communityForm?id=$id';
  static String announcementForm(String communityId) => '/community/manage/announcement?club=$communityId';
  static const tenantInfo = '/profile/tenant-info'; // owners
  static const tenantForm = '/profile/tenant-info/edit';
}
