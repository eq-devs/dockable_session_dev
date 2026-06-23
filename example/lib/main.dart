import 'package:dockable_session_dev/dockable_session_dev.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Persistent Session Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  late final SessionController _controller = SessionController(vsync: this);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opens a session, or replaces the current one and brings it to the front.
  void _present({
    required SessionContentBuilder builder,
    required String title,
  }) {
    if (_controller.hasSession) {
      _controller.replace(builder: builder, title: title);
      _controller.restore();
    } else {
      _controller.open(builder: builder, title: title);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The overlay is unopinionated about navigation: we build our own Scaffold,
    // tabs (IndexedStack), and bottom bar, and stack the session on top.
    return SessionOverlay(
      controller: _controller,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            _Launcher(onPresent: _present),
            const _About(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Launcher',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.info_outline),
              activeIcon: Icon(Icons.info),
              label: 'About',
            ),
          ],
        ),
      ),
    );
  }
}

/// First tab: buttons that open each kind of session.
class _Launcher extends StatelessWidget {
  const _Launcher({required this.onPresent});

  final void Function({
    required SessionContentBuilder builder,
    required String title,
  }) onPresent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Launcher')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Open a session, minimize it to the pill, switch tabs, then '
            'restore — its scroll position and input survive completely.',
          ),
          const SizedBox(height: 16),
          _LaunchCard(
            icon: Icons.article_outlined,
            title: 'Article',
            subtitle: 'Long scroll list — scroll, minimize, restore.',
            onTap: () => onPresent(
              title: 'Article',
              builder: (_, controller) =>
                  _ArticleSession(controller: controller),
            ),
          ),
          _LaunchCard(
            icon: Icons.chat_bubble_outline,
            title: 'Chat',
            subtitle: 'Counter + text field — state is preserved.',
            onTap: () => onPresent(
              title: 'Chat',
              builder: (_, controller) => _ChatSession(controller: controller),
            ),
          ),
          _LaunchCard(
            icon: Icons.public,
            title: 'URL session (WebView stub)',
            subtitle: 'Mimics a Custom Tab; tracks lastUrl as a fallback.',
            onTap: () => onPresent(
              title: 'example.com',
              builder: (_, controller) => _UrlSession(controller: controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchCard extends StatelessWidget {
  const _LaunchCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_full),
        onTap: onTap,
      ),
    );
  }
}

class _About extends StatelessWidget {
  const _About();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This tab keeps its own state via IndexedStack while the single '
            'session floats above it. Only one session exists at a time.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Reusable chrome: an app bar with minimize + close wired to the session
/// controller in scope.
class _SessionChrome extends StatelessWidget {
  const _SessionChrome({
    required this.controller,
    required this.title,
    required this.child,
  });

  final SessionController controller;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Minimize',
            icon: const Icon(Icons.remove),
            onPressed: controller.minimize,
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: controller.close,
          ),
        ],
      ),
      body: child,
    );
  }
}

class _ArticleSession extends StatelessWidget {
  const _ArticleSession({required this.controller});
  final SessionController controller;
  @override
  Widget build(BuildContext context) {
    return _SessionChrome(
      controller: controller,
      title: 'Article',
      child: ListView.builder(
        itemCount: 60,
        itemBuilder: (context, i) => ListTile(
          leading: CircleAvatar(child: Text('$i')),
          title: Text('Paragraph $i'),
          subtitle: const Text(
            'Scroll down, minimize, switch tabs, then restore. '
            'This position is exactly where you left it.',
          ),
        ),
      ),
    );
  }
}

class _ChatSession extends StatefulWidget {
  const _ChatSession({required this.controller});
  final SessionController controller;
  @override
  State<_ChatSession> createState() => _ChatSessionState();
}

class _ChatSessionState extends State<_ChatSession> {
  final _messages = <String>['Welcome 👋'];
  final _field = TextEditingController();

  void _send() {
    final text = _field.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(text);
      _field.clear();
    });
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SessionChrome(
      controller: widget.controller,
      title: 'Chat (${_messages.length})',
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final m in _messages)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(m),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _field,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Type, minimize, restore — text stays',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _send),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A WebView stand-in (doc §8 stub). It keeps no native WebView but records
/// [SessionEntry.lastUrl] so a real implementation could rebuild after the OS
/// reclaims the view.
class _UrlSession extends StatefulWidget {
  const _UrlSession({required this.controller});
  final SessionController controller;
  @override
  State<_UrlSession> createState() => _UrlSessionState();
}

class _UrlSessionState extends State<_UrlSession> {
  final _address = TextEditingController(text: 'https://example.com');

  void _go() {
    widget.controller.entry?.lastUrl = _address.text;
    setState(() {});
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SessionChrome(
      controller: widget.controller,
      title: 'Browser',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _address,
              onSubmitted: (_) => _go(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _go,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Text(
                'Rendering\n${_address.text}\n\n(WebView stub)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
