/// Chooses one deterministic initiator for a direct-message peer pair.
///
/// This pure rule is shared by the UI connection request and the transport
/// factory without either layer depending on the other's implementation.
bool isDirectMessageCaller({required int selfId, required int friendId}) =>
    selfId < friendId;
