import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/network/api_exception.dart';
import 'package:the_grids/core/router/app_router.dart';
import 'package:the_grids/core/router/routes.dart';
import 'package:the_grids/features/auth/domain/user_role.dart';

import '../helpers/community_fakes.dart';
import '../helpers/pump_app.dart';

Finder _appBarTitle(String text) => find.descendant(of: find.byType(AppBar), matching: find.text(text));

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  Future<FakeCommunityRepository> openTab(WidgetTester tester, UserRole role) async {
    final community = FakeCommunityRepository(admin: role == UserRole.admin);
    final container = await pumpGridsApp(tester, community: community);
    await signInAs(tester, container, role);
    container.read(routerProvider).go(AppRoutes.community);
    await tester.pumpAndSettle();
    return community;
  }

  group('Polls', () {
    testWidgets('residents vote once and then see the results', (tester) async {
      final community = await openTab(tester, UserRole.owner);

      expect(_appBarTitle('Community'), findsOneWidget);
      expect(find.text('Which activity for Sunday?'), findsOneWidget);
      expect(find.text('Results appear after you vote.'), findsOneWidget);
      expect(find.textContaining('votes ('), findsNothing); // no counts before voting
      expect(find.text('New Poll'), findsNothing);
      expect(find.text('New Community'), findsNothing);

      await tester.tap(find.text('Karaoke'));
      await tester.pump();
      await tester.tap(find.text('Vote'));
      await tester.pumpAndSettle();

      expect(community.votes, [('poll1', 'o2')]);
      expect(find.text('Thanks for voting!'), findsOneWidget);
      expect(find.text('9 votes (41%)'), findsOneWidget);
      expect(find.text('8 votes (36%)'), findsOneWidget);
      expect(find.text('5 votes (23%)'), findsOneWidget);
      expect(find.textContaining('You voted for: '), findsOneWidget);
      expect(find.bySemanticsLabel('Karaoke, 8 votes (36%), your vote'), findsOneWidget);
    });

    testWidgets('a second vote is refused with a clear message', (tester) async {
      final community = await openTab(tester, UserRole.tenant);
      community.voteError = const ApiException(code: 'ALREADY_VOTED', message: 'dup');

      await tester.tap(find.text('Movie Night'));
      await tester.pump();
      await tester.tap(find.text('Vote'));
      await tester.pumpAndSettle();
      expect(find.text('You have already voted in this poll.'), findsOneWidget);
    });

    testWidgets('admins see live results and can close a poll', (tester) async {
      final community = await openTab(tester, UserRole.admin);

      expect(find.text('9 votes (43%)'), findsOneWidget);
      expect(find.text('Vote'), findsNothing);
      expect(find.text('New Poll'), findsOneWidget);

      await tester.tap(find.byTooltip('Poll options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close poll').last);
      await tester.pumpAndSettle();
      expect(find.text('Close this poll? No more votes will be accepted.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Close poll'));
      await tester.pumpAndSettle();

      expect(community.closedPolls, ['poll1']);
      expect(find.textContaining('Closed'), findsOneWidget);
    });

    testWidgets('admins create a poll with distinct options', (tester) async {
      final community = await openTab(tester, UserRole.admin);
      await tester.tap(find.text('New Poll'));
      await tester.pumpAndSettle();
      expect(_appBarTitle('New Poll'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Question'), 'Diwali celebration venue?');
      await tester.enterText(find.widgetWithText(TextFormField, 'Option 1'), 'Clubhouse');
      await tester.enterText(find.widgetWithText(TextFormField, 'Option 2'), 'clubhouse');
      await tester.tap(find.text('Create Poll'));
      await tester.pumpAndSettle();
      expect(find.text('This option is already listed.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Option 2'), 'Terrace');
      await tester.tap(find.text('Add option'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Option 3'), 'Garden');
      await _scrollTo(tester, find.text('Create Poll'));
      await tester.tap(find.text('Create Poll'));
      await tester.pumpAndSettle();

      final created = community.createdPolls.single;
      expect(created.question, 'Diwali celebration venue?');
      expect(created.options, ['Clubhouse', 'Terrace', 'Garden']);
      expect(created.closesAt, isNull);
      expect(find.text('Poll created. Residents have been notified.'), findsOneWidget);
    });
  });

  group('Clubs', () {
    testWidgets('residents open a club, read announcements and join', (tester) async {
      final community = await openTab(tester, UserRole.tenant);
      await _scrollTo(tester, find.text('Yoga Club'));
      expect(find.textContaining('Sanskriti Kadam: Breathing for Balance'), findsOneWidget);

      await tester.tap(find.text('Yoga Club'));
      await tester.pumpAndSettle();
      expect(_appBarTitle('Yoga Club'), findsOneWidget);
      expect(find.text('1 member'), findsOneWidget);
      expect(find.text('Community Hall Terrace'), findsOneWidget);
      expect(find.text('Add Announcement'), findsNothing);

      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      expect(find.text('You joined Yoga Club'), findsOneWidget);
      expect(find.text('2 members'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
      expect(community.clubs['c1']!.community.isMember, isTrue);
    });

    testWidgets('admins create a club with members', (tester) async {
      final community = await openTab(tester, UserRole.admin);
      await tester.tap(find.text('New Community'));
      await tester.pumpAndSettle();
      expect(_appBarTitle('New Community'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Kids Zone');
      await tester.enterText(find.widgetWithText(TextField, 'Search by name or flat'), 'tower-a');
      await tester.pumpAndSettle();
      expect(find.text('Shruti Chetan Dalvi'), findsNothing);
      await tester.tap(find.text('Kiran Rathod'));
      await tester.tap(find.text('Mehul Shah'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await _scrollTo(tester, find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final created = community.createdClubs.single;
      expect(created.name, 'Kids Zone');
      expect(created.memberIds, unorderedEquals(['u2', 'u3']));
      expect(_appBarTitle('Kids Zone'), findsOneWidget);
      expect(find.text('2 members'), findsOneWidget);
    });

    testWidgets('admins post an announcement with an event time', (tester) async {
      final community = await openTab(tester, UserRole.admin);
      await _scrollTo(tester, find.text('Yoga Club'));
      await tester.tap(find.text('Yoga Club'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Announcement'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Sunrise session');
      await tester.enterText(find.widgetWithText(TextFormField, 'Description'), 'Meet on the terrace.');
      await tester.enterText(find.widgetWithText(TextFormField, 'Venue'), 'Terrace');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final (clubId, input) = community.createdAnnouncements.single;
      expect(clubId, 'c1');
      expect(input.title, 'Sunrise session');
      expect(input.venue, 'Terrace');
      expect(input.eventAt, isNull);
      expect(find.text('Announcement saved'), findsOneWidget);
    });
  });
}
