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
  name: "Test proposal creation with milestones",
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
    
    const milestones = [
      {
        title: "Milestone 1",
        description: "First milestone",
        deadline: 100,
        funds: 500,
        status: "pending"
      },
      {
        title: "Milestone 2", 
        description: "Second milestone",
        deadline: 200,
        funds: 500,
        status: "pending"
      }
    ];
    
    // Create proposal with milestones
    block = chain.mineBlock([
      Tx.contractCall('sphere_dao', 'create-proposal', [
        types.ascii("Test Proposal"),
        types.ascii("Description"),
        types.uint(100),
        types.uint(1000),
        types.list(milestones.map(m => ({
          title: types.ascii(m.title),
          description: types.ascii(m.description),
          deadline: types.uint(m.deadline),
          funds: types.uint(m.funds),
          status: types.ascii(m.status)
        })))
      ], wallet1.address)
    ]);
    block.receipts[0].result.expectOk();
    
    // Vote on milestone
    block = chain.mineBlock([
      Tx.contractCall('sphere_dao', 'vote-on-milestone', [
        types.uint(1),
        types.uint(0),
        types.bool(true)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk();
    
    // Complete milestone
    block = chain.mineBlock([
      Tx.contractCall('sphere_dao', 'complete-milestone', [
        types.uint(1),
        types.uint(0)
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
