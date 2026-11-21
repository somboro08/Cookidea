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
    final inviteToken = Uri.base.queryParameters['invite'];
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null) return AuthPage(inviteToken: inviteToken);
        return DashboardPage(supabaseEnabled: true, pendingInvitationToken: inviteToken);
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.inviteToken});
  final String? inviteToken;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _otp = TextEditingController();
  bool _register = false;
  bool _otpSent = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose(); _password.dispose(); _name.dispose(); _otp.dispose();
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


  Future<void> _sendOtp() async {
    if (!_email.text.trim().contains('@')) { setState(() => _error = 'Saisissez une adresse e-mail valide.'); return; }
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await Supabase.instance.client.auth.signInWithOtp(email: _email.text.trim(), shouldCreateUser: false);
      if (mounted) setState(() { _otpSent = true; _notice = 'Un code de connexion vient d’être envoyé à votre adresse e-mail.'; });
    } on AuthException catch (e) { if (mounted) setState(() => _error = e.message); }
    catch (_) { if (mounted) setState(() => _error = 'Impossible d’envoyer le code. Réessayez.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _verifyOtp() async {
    if (_otp.text.trim().length < 6) { setState(() => _error = 'Saisissez le code reçu par e-mail.'); return; }
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await Supabase.instance.client.auth.verifyOTP(email: _email.text.trim(), token: _otp.text.trim(), type: OtpType.email);
    } on AuthException catch (e) { if (mounted) setState(() => _error = e.message); }
    catch (_) { if (mounted) setState(() => _error = 'Code invalide ou expiré. Demandez un nouveau code.'); }
    finally { if (mounted) setState(() => _busy = false); }
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
                  if (widget.inviteToken != null && widget.inviteToken!.isNotEmpty) ...[
                    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: p.goldTint, borderRadius: BorderRadius.circular(12)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.mail_outline), SizedBox(width: 10), Expanded(child: Text('Vous avez reçu une invitation à rejoindre un projet Cookidea. Connectez-vous ou créez un compte avec l’adresse e-mail invitée pour l’accepter.')),
                    ])),
                    const SizedBox(height: 18),
                  ],
                  if (_register) ...[
                    TextField(controller:_name, textCapitalization:TextCapitalization.words, decoration:const InputDecoration(labelText:'Nom complet',prefixIcon:Icon(AppIcons.user))),
                    const SizedBox(height:14),
                  ],
                  TextField(controller:_email, keyboardType:TextInputType.emailAddress, decoration:const InputDecoration(labelText:'Adresse e-mail',prefixIcon:Icon(AppIcons.mail))),
                  const SizedBox(height:14),
                  if (!_otpSent) TextField(controller:_password, obscureText:!_showPassword, decoration:InputDecoration(labelText:'Mot de passe',prefixIcon:const Icon(AppIcons.lock),suffixIcon:IconButton(onPressed:()=>setState(()=>_showPassword=!_showPassword),icon:Icon(_showPassword?Icons.visibility_off:Icons.visibility)))),
                  if (_otpSent) ...[const SizedBox(height:14),TextField(controller:_otp,keyboardType:TextInputType.number,maxLength:8,decoration:const InputDecoration(labelText:'Code reçu par e-mail',prefixIcon:Icon(Icons.password),counterText:''))],
                  if (_error != null) ...[const SizedBox(height:14),Text(_error!,style:TextStyle(color:p.danger))],
                  if (_notice != null) ...[const SizedBox(height:14),Text(_notice!,style:TextStyle(color:p.success))],
                  const SizedBox(height:22),
                  FilledButton(
                    onPressed:_busy?null:(_otpSent?_verifyOtp:_submit),
                    style:FilledButton.styleFrom(backgroundColor:p.gold,foregroundColor:p.onGold,padding:const EdgeInsets.symmetric(vertical:17)),
                    child:_busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):Text(_register?'Créer mon compte':_otpSent?'Vérifier le code':'Se connecter'),
                  ),
                  const SizedBox(height:12),
                  if (!_otpSent) TextButton(onPressed:()=>setState((){_register=!_register;_error=null;_notice=null;}),child:Text(_register?'J’ai déjà un compte':'Créer un compte')),
                  if (!_register && !_otpSent) TextButton(onPressed:_busy?null:_sendOtp,child:const Text('Recevoir un code par e-mail')),
                  if (_otpSent) TextButton(onPressed:_busy?null:()=>setState(()=>_otpSent=false),child:const Text('Utiliser mon mot de passe')),
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
