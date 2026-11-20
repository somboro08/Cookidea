import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../dashboard/presentation/dashboard_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.supabaseEnabled});
  final bool supabaseEnabled;

  @override
  Widget build(BuildContext context) {
    if (!supabaseEnabled) return const DashboardPage(supabaseEnabled: false);
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null) return const AuthPage();
        return const DashboardPage(supabaseEnabled: true);
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose(); _password.dispose(); _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.length < 6) {
      setState(() => _error = 'Saisissez un e-mail et un mot de passe d’au moins 6 caractères.');
      return;
    }
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (_register) {
        final result = await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'full_name': _name.text.trim()},
        );
        if (result.session == null && mounted) {
          setState(() => _notice = 'Compte créé. Vérifiez votre boîte mail pour confirmer votre adresse.');
        }
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Une erreur est survenue. Réessayez dans un instant.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              color: p.card,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(width:44,height:44,decoration:BoxDecoration(color:p.gold,borderRadius:BorderRadius.circular(14)),child:Icon(AppIcons.idea,color:p.onGold,size:25)),
                    const SizedBox(width:12),
                    Text('cookidea',style:Theme.of(context).textTheme.titleLarge),
                  ]),
                  const SizedBox(height:32),
                  Text(_register ? 'Créez votre espace' : 'Ravi de vous revoir',style:Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height:8),
                  Text(_register ? 'Une idée mérite un endroit pour grandir.' : 'Connectez-vous pour retrouver vos projets.',style:Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height:26),
                  if (_register) ...[
                    TextField(controller:_name, textCapitalization:TextCapitalization.words, decoration:const InputDecoration(labelText:'Nom complet',prefixIcon:Icon(AppIcons.user))),
                    const SizedBox(height:14),
                  ],
                  TextField(controller:_email, keyboardType:TextInputType.emailAddress, decoration:const InputDecoration(labelText:'Adresse e-mail',prefixIcon:Icon(AppIcons.mail))),
                  const SizedBox(height:14),
                  TextField(controller:_password, obscureText:!_showPassword, decoration:InputDecoration(labelText:'Mot de passe',prefixIcon:const Icon(AppIcons.lock),suffixIcon:IconButton(onPressed:()=>setState(()=>_showPassword=!_showPassword),icon:Icon(_showPassword?Icons.visibility_off:Icons.visibility)))),
                  if (_error != null) ...[const SizedBox(height:14),Text(_error!,style:TextStyle(color:p.danger))],
                  if (_notice != null) ...[const SizedBox(height:14),Text(_notice!,style:TextStyle(color:p.success))],
                  const SizedBox(height:22),
                  FilledButton(
                    onPressed:_busy?null:_submit,
                    style:FilledButton.styleFrom(backgroundColor:p.gold,foregroundColor:p.onGold,padding:const EdgeInsets.symmetric(vertical:17)),
                    child:_busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):Text(_register?'Créer mon compte':'Se connecter'),
                  ),
                  const SizedBox(height:12),
                  TextButton(onPressed:()=>setState((){_register=!_register;_error=null;_notice=null;}),child:Text(_register?'J’ai déjà un compte':'Créer un compte')),
                  if (!_register) TextButton(onPressed:() async {
                    if (_email.text.trim().isEmpty) { setState(()=>_error='Saisissez votre adresse e-mail.'); return; }
                    try {
                      await Supabase.instance.client.auth.resetPasswordForEmail(_email.text.trim());
                      if (mounted) setState(()=>_notice='Un lien de réinitialisation vous a été envoyé.');
                    } on AuthException catch(e) { if(mounted)setState(()=>_error=e.message); }
                  },child:const Text('Mot de passe oublié ?')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
