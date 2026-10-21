import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  String? _error;
  bool _trusted = false;

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
        _error = null;
        _trusted = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _peerInvitation = null;
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
        confirmedFingerprint: invitation.fingerprint,
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
    return AlertDialog(
      title: const Text('Peer identity trust'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Compare the fingerprint with your friend through an independent channel before confirming trust.',
              ),
              if (_localInvitation != null) ...[
                const SizedBox(height: 16),
                const Text('Your trust invitation'),
                SelectableText(_localInvitation!),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: _localInvitation!),
                    ),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy invitation'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _invitationController,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Peer trust invitation',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_peerInvitation != null) ...[
                const SizedBox(height: 12),
                Text('Device: ${_peerInvitation!.deviceId}'),
                SelectableText('Fingerprint: ${_peerInvitation!.fingerprint}'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _trusted ? null : _confirmTrust,
                  icon: Icon(_trusted ? Icons.verified : Icons.shield),
                  label: Text(_trusted ? 'Trusted' : 'Confirm and trust'),
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
          child: const Text('Close'),
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
