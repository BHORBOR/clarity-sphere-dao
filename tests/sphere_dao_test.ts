import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Test member management functions",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Add initial admin
    let block = chain.mineBlock([
      Tx.contractCall('sphere_dao', 'add-member', [
        types.principal(deployer.address),
        types.ascii("admin")
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk();
    
    // Add regular member
    block = chain.mineBlock([
      Tx.contractCall('sphere_dao', 'add-member', [
        types.principal(wallet1.address),
        types.ascii("member")
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk();
    
    // Check member info
    let memberInfo = chain.callReadOnlyFn(
      'sphere_dao',
      'get-member-info',
      [types.principal(wallet1.address)],
      deployer.address
    );
    memberInfo.result.expectSome();
  },
});

Clarinet.test({
  name: "Test proposal creation and voting",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Setup members
    let block = chain.mineBlock([
      Tx.contractCall('sphere_dao', 'add-member', [
        types.principal(deployer.address),
        types.ascii("admin")
      ], deployer.address),
      Tx.contractCall('sphere_dao', 'add-member', [
        types.principal(wallet1.address),
        types.ascii("member")
      ], deployer.address)
    ]);
    
    // Create proposal
    block = chain.mineBlock([
      Tx.contractCall('sphere_dao', 'create-proposal', [
        types.ascii("Test Proposal"),
        types.ascii("Description"),
        types.uint(100),
        types.uint(1000)
      ], wallet1.address)
    ]);
    block.receipts[0].result.expectOk();
    
    // Vote on proposal
    block = chain.mineBlock([
      Tx.contractCall('sphere_dao', 'vote-on-proposal', [
        types.uint(1),
        types.bool(true)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Test treasury management",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    // Deposit funds
    let block = chain.mineBlock([
      Tx.contractCall('sphere_dao', 'deposit-funds', [
        types.uint(1000)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk();
    
    // Check balance
    let balance = chain.callReadOnlyFn(
      'sphere_dao',
      'get-treasury-balance',
      [],
      deployer.address
    );
    assertEquals(balance.result.expectOk(), types.uint(1000));
  },
});