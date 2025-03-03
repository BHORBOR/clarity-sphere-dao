// [Previous test imports remain unchanged]

Clarinet.test({
  name: "Test milestone deadline validation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    // Test invalid milestone deadline
    let block = chain.mineBlock([
      Tx.contractCall('sphere_dao', 'create-proposal', [
        types.ascii("Test"),
        types.ascii("Description"),
        types.uint(30), // Proposal deadline
        types.uint(1000),
        types.list([{
          title: types.ascii("M1"),
          description: types.ascii("M1 Desc"),
          deadline: types.uint(35), // Invalid: later than proposal deadline
          funds: types.uint(500),
          status: types.ascii("pending")
        }])
      ], deployer.address)
    ]);
    block.receipts[0].result.expectErr(110); // ERR_INVALID_MILESTONE_DEADLINE
  }
});

// [Rest of test file remains unchanged]
