export function buildAllocationDisputeDeliveryRequest({
  allocationId,
  comment,
}) {
  return {
    mutation: `
    mutation DisputeDelivery($id: ID!, $comment: String!) {
      allocationDisputeDelivery(id: $id, comment: $comment) {
        id
        state
      }
    }
  `,
    variables: {
      id: allocationId,
      comment,
    },
  };
}
