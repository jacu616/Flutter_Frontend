import 'package:flutter/material.dart';
import 'auth/signup.dart';
import 'auth/login.dart';
import 'home/dashboard_screen.dart';
import 'success.dart'; // <--- Import Success Page

// Feature pages
import 'home/tabs/feed.dart';
import 'home/tabs/join/search.dart';
import 'home/tabs/join/trip_join.dart';
import 'home/tabs/join/join_verification.dart';
import 'home/tabs/join/join_payment.dart'; // <--- Import Payment Page
import 'home/tabs/profile.dart';
import 'home/tabs/trip/trip_details.dart';
import 'home/tabs/trip/route_details.dart';
import 'home/tabs/trip/payment_details.dart';
import 'home/tabs/trip/contact_details.dart'; 
import 'home/tabs/groups/group.dart'; 

class AppRoutes {
  static const String signup = '/signup';
  static const String login = '/login';
  static const String home = '/home';
  
  // Feature routes
  static const String feed = '/feed';
  static const String search = '/search';
  static const String tripJoin = '/trip-join';
  static const String joinVerification = '/join-verification';
  static const String joinPayment = '/join-payment'; // <--- New Route
  static const String success = '/success';          // <--- New Route
  
  static const String profile = '/profile';
  static const String tripDetails = '/trip-details';
  static const String routeDetails = '/route-details';
  static const String paymentDetails = '/payment-details';
  static const String contactDetails = '/contact-details'; 
  static const String groupChat = '/group-chat';

  static Map<String, WidgetBuilder> routes = {
    signup: (context) => const SignupPage(),
    login: (context) => const LoginPage(),
    home: (context) => const DashboardScreen(),
    
    feed: (context) => const HomeFeed(),         
    search: (context) => const SearchGrid(),
    tripJoin: (context) => const TripJoinPage(),
    joinVerification: (context) => const JoinVerificationPage(),
    joinPayment: (context) => const JoinPaymentPage(), // <--- New Builder
    success: (context) => const SuccessPage(),         // <--- New Builder
    
    profile: (context) => const UserProfile(),    
    tripDetails: (context) => const TripDetailsPage(),
    routeDetails: (context) => const RouteDetailsPage(),
    paymentDetails: (context) => const PaymentDetailsPage(),
    contactDetails: (context) => const ContactDetailsPage(), 
    groupChat: (context) => const GroupPage(),
  };
}