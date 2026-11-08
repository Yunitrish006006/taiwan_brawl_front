import 'couple_relationship.dart';

class CoupleRequest {
  const CoupleRequest({
    required this.id,
    required this.requesterUserId,
    required this.recipientUserId,
    required this.startedOn,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.relationshipId,
  });
  final String id, startedOn, status;
  final int requesterUserId, recipientUserId;
  final DateTime createdAt, expiresAt;
  final String? relationshipId;
  factory CoupleRequest.fromJson(Map<String, dynamic> j) => CoupleRequest(
    id: j['id'] as String,
    requesterUserId: j['requesterUserId'] as int,
    recipientUserId: j['recipientUserId'] as int,
    startedOn: j['startedOn'] as String,
    status: j['status'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    expiresAt: DateTime.parse(j['expiresAt'] as String),
    relationshipId: j['relationshipId'] as String?,
  );
}

class CoupleDateProposal {
  const CoupleDateProposal({
    required this.id,
    required this.relationshipId,
    required this.requesterUserId,
    required this.startedOn,
    required this.baseVersion,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });
  final String id, relationshipId, startedOn, status;
  final int requesterUserId, baseVersion;
  final DateTime createdAt, expiresAt;
  factory CoupleDateProposal.fromJson(Map<String, dynamic> j) =>
      CoupleDateProposal(
        id: j['id'] as String,
        relationshipId: j['relationshipId'] as String,
        requesterUserId: j['requesterUserId'] as int,
        startedOn: j['startedOn'] as String,
        baseVersion: j['baseVersion'] as int,
        status: j['status'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
      );
}

class CouplesOverview {
  const CouplesOverview({
    required this.serverNow,
    required this.relationship,
    required this.incomingRequests,
    required this.outgoingRequests,
    required this.dateProposal,
  });
  final DateTime serverNow;
  final CoupleRelationship? relationship;
  final List<CoupleRequest> incomingRequests, outgoingRequests;
  final CoupleDateProposal? dateProposal;
  factory CouplesOverview.fromJson(Map<String, dynamic> json) {
    if (json['ok'] != true) {
      throw const FormatException('Invalid couples response');
    }
    final data = json['data'] as Map<String, dynamic>;
    final relationship = data['relationship'];
    final proposal = data['dateProposal'];
    if (relationship != null &&
        (relationship as Map<String, dynamic>)['status'] != 'active') {
      throw const FormatException('Overview relationship must be active');
    }
    return CouplesOverview(
      serverNow: DateTime.parse(json['serverNow'] as String),
      relationship: relationship == null
          ? null
          : CoupleRelationship.fromJson(relationship as Map<String, dynamic>),
      incomingRequests: List.unmodifiable(
        (data['incomingRequests'] as List).map(
          (e) => CoupleRequest.fromJson(e as Map<String, dynamic>),
        ),
      ),
      outgoingRequests: List.unmodifiable(
        (data['outgoingRequests'] as List).map(
          (e) => CoupleRequest.fromJson(e as Map<String, dynamic>),
        ),
      ),
      dateProposal: proposal == null
          ? null
          : CoupleDateProposal.fromJson(proposal as Map<String, dynamic>),
    );
  }
}
