import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/locale_provider.dart';
import '../services/peer_trust_service.dart';
import '../services/secure_device_identity.dart';

/// Explicit user-confirmed trust ceremony for serverless P2P pairing.
class PeerTrustDialog extends StatefulWidget {
  const PeerTrustDialog({
    super.key,
    required this.trustService,
    this.localIdentity,
  });

  final PeerTrustService trustService;
  final SecureDeviceIdentity? localIdentity;

  @override
  State<PeerTrustDialog> createState() => _PeerTrustDialogState();
}

class _PeerTrustDialogState extends State<PeerTrustDialog> {
  late final TextEditingController _invitationController;
  String? _localInvitation;
  PeerTrustInvitation? _peerInvitation;
  String _fingerprintConfirmation = '';
  String? _error;
  bool _trusted = false;

  Map<String, String> get _t => context.read<LocaleProvider>().translation;

  String _normalizeFingerprint(String value) {
    final normalized = value.replaceAll(RegExp(r'[\s:-]'), '');
    if (!RegExp(r'^[0-9a-fA-F]*$').hasMatch(normalized)) return '';
    return normalized.toLowerCase();
  }

  bool get _fingerprintMatches {
    final invitation = _peerInvitation;
    final confirmation = _normalizeFingerprint(_fingerprintConfirmation);
    return invitation != null &&
        confirmation.isNotEmpty &&
        confirmation == invitation.fingerprint.toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _invitationController = TextEditingController()
      ..addListener(_parseInvitation);
    final identity = widget.localIdentity;
    if (identity != null) {
      _localInvitation = widget.trustService
          .createInvitation(identity)
          .encode();
    }
  }

  @override
  void dispose() {
    _invitationController.dispose();
    super.dispose();
  }

  void _parseInvitation() {
    final text = _invitationController.text.trim();
    if (text.isEmpty) {
      if (_peerInvitation != null || _error != null) {
        setState(() {
          _peerInvitation = null;
          _fingerprintConfirmation = '';
          _error = null;
        });
      }
      return;
    }
    try {
      final invitation = PeerTrustInvitation.decode(text);
      if (!mounted) return;
      setState(() {
        _peerInvitation = invitation;
        _fingerprintConfirmation = '';
        _error = null;
        _trusted = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _peerInvitation = null;
        _fingerprintConfirmation = '';
        _error = error.toString();
        _trusted = false;
      });
    }
  }

  Future<void> _confirmTrust() async {
    final invitation = _peerInvitation;
    if (invitation == null) return;
    try {
      await widget.trustService.trustInvitation(
        _invitationController.text.trim(),
        confirmedFingerprint: _normalizeFingerprint(_fingerprintConfirmation),
      );
      if (!mounted) return;
      setState(() => _trusted = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return AlertDialog(
      title: Text(t.text('Peer identity trust')),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.text(
                  'Use the fingerprint your friend gave you through a separate channel. Enter it exactly to continue.',
                ),
              ),
              if (_localInvitation != null) ...[
                const SizedBox(height: 16),
                Text(t.text('Your Ed25519 public-key invitation')),
                Text(t.text('Contains no private signing key.')),
                SelectableText(_localInvitation!),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: _localInvitation!),
                    ),
                    icon: const Icon(Icons.copy),
                    label: Text(t.text('Copy invitation')),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('peer-trust-invitation'),
                controller: _invitationController,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: t.text('Peer trust invitation'),
                  border: OutlineInputBorder(),
                ),
              ),
              if (_peerInvitation != null) ...[
                const SizedBox(height: 12),
                Text('${t.text('Device')}: ${_peerInvitation!.deviceId}'),
                Text(
                  _peerInvitation!.algorithm == 'ed25519'
                      ? t.text('Ed25519 public key')
                      : t.text(
                          'Legacy shared secret — import only through a private channel.',
                        ),
                ),
                SelectableText(
                  '${t.text('Fingerprint')}: ${_peerInvitation!.fingerprint}',
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('peer-fingerprint-confirmation'),
                  onChanged: (value) => setState(() {
                    _fingerprintConfirmation = value;
                  }),
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: t.text(
                      'Fingerprint confirmed through separate channel',
                    ),
                    hintText: t.text(
                      'Enter the fingerprint you compared with your friend',
                    ),
                    border: const OutlineInputBorder(),
                    errorText:
                        _fingerprintConfirmation.isNotEmpty &&
                            !_fingerprintMatches
                        ? t.text(
                            'This fingerprint does not match the invitation.',
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _trusted || !_fingerprintMatches
                      ? null
                      : _confirmTrust,
                  icon: Icon(_trusted ? Icons.verified : Icons.shield),
                  label: Text(
                    _trusted ? t.text('Trusted') : t.text('Confirm and trust'),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Colors.red.shade700)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.text('Close')),
        ),
      ],
    );
  }
}

Future<void> showPeerTrustDialog(
  BuildContext context, {
  required PeerTrustService trustService,
  SecureDeviceIdentity? localIdentity,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => PeerTrustDialog(
      trustService: trustService,
      localIdentity: localIdentity,
    ),
  );
}
