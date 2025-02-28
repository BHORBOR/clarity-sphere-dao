// [Previous test imports and initial tests remain unchanged]

Clarinet.test({
  name: "Test double voting prevention",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Setup and create proposal [previous setup code]
    
    // First vote should succeed
    let block = chain.mineBlock([
      Tx.contractCall('sphere_dao', 'vote-on-proposal', [
        types.uint(1),
        types.bool(true)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk();
    
    // Second vote should fail
    block = chain.mineBlock([
      Tx.contractCall('sphere_dao', 'vote-on-proposal', [
        types.uint(1),
        types.bool(true)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectErr(107); // ERR_ALREADY_VOTED
  }
});

// [Rest of the test file remains unchanged]
