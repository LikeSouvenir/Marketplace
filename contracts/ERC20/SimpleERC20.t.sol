// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SimpleERC20.sol";
import {Test} from "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";

contract SimpleERC20Test is Test {
    using stdStorage for StdStorage;
    SimpleERC20 simpleERC20;
    string defaultName = "DefName";
    string defaultSymbol = "DN";

    event Transfer(address indexed from, address indexed to, uint value);
    event Approve(address indexed from, address indexed to, uint value);
    address account1 = vm.addr(1);
    address account2 = vm.addr(2);
    address account3 = vm.addr(3);
    uint value = 10000;

    function setUp() public {
        simpleERC20 = new SimpleERC20(defaultName, defaultSymbol);
    }

    function test_name() public view{
        string memory checkName = simpleERC20.name();
        vm.assertEq(checkName, defaultName);
    }

    function test_symbol() public view{
        string memory checkSymbol = simpleERC20.symbol();
        vm.assertEq(checkSymbol, defaultSymbol);
    }
    
    function test_totalSupply() public{
        simpleERC20.mint(account1, value);

        uint totalSupply = simpleERC20.totalSupply();
        
        vm.assertEq(totalSupply, value);
    }

    function test_decimals() public view{
        uint8 defaultDecimals = uint8(uint256(vm.load(address(simpleERC20), bytes32(uint256(2)))));
        uint8 currentDecimals = simpleERC20.decimals();

        assertEq(currentDecimals, defaultDecimals);
    }

    function test_balanceOf() public {
        deal(address(simpleERC20), account1, value);
        assertEq(simpleERC20.balanceOf(account1), value);
    }

    function test_approveWithAllownace() public {
        deal(address(simpleERC20), account2, value);
        vm.startPrank(account2);
        simpleERC20.approve(account3, value);
        assertEq(simpleERC20.allowance(account2, account3), value);
    }

    function test_approveWithSlot() public {
        uint slot = uint256(keccak256(abi.encode(account2, uint256(5))));
        bytes32 key = keccak256(abi.encode(account3, slot));
        vm.store(address(simpleERC20), key, bytes32(value));
        assertEq(simpleERC20.allowance(account2, account3), value);
    }

    function test_approveEmit() public {
        vm.expectEmit(true,true,false, true);
        emit Approve(account2, account3, value);
        test_approveWithAllownace();
    }

    function test_allowanceWithApprove() public {
        vm.startPrank(account2);
        simpleERC20.approve(account3, value);
        assertEq(simpleERC20.allowance(account2, account3), value);
    }

    function test_allowanceWithSlot( ) public {
        vm.store(
            address(simpleERC20), 
            keccak256(abi.encode(account3, keccak256(abi.encode(account2, uint256(5))))), 
            bytes32(uint256(value))
        );
        assertEq(simpleERC20.allowance(account2, account3), value);
    }

    function test_transfer() public {
        deal(address(simpleERC20), account2, value);
        vm.prank(account2);
        simpleERC20.transfer(account3, value);
        assertEq(simpleERC20.balanceOf(account3), value);
    }

    function test_transferEmit() public {
        vm.expectEmit(true,true,false, true);
        emit Transfer(account2, account3, value);
        test_transfer();
    }

    function test_mint()public {
        simpleERC20.mint(account1, value);
        assertEq(simpleERC20.balanceOf(account1), value);
    }

    function test_transferFrom() public {
        test_mint();
        
        vm.prank(account1);
        simpleERC20.approve(account3, value);
        assertEq(simpleERC20.allowance(account1, account3), value);

        
        vm.prank(account3);
        simpleERC20.transferFrom(account1, account2, value);
        
        assertEq(simpleERC20.balanceOf(account2), value);
    }

    function test_burn() public {
        test_mint();
        assertEq(simpleERC20.balanceOf(account1), value);
        vm.prank(account1);
        simpleERC20.burn(value);
        assertEq(simpleERC20.balanceOf(account1), 0);
    }

    function test_burnFrom() public {
        test_mint();
        
        vm.prank(account1);
        simpleERC20.approve(account3, value);
        assertEq(simpleERC20.allowance(account1, account3), value);

        vm.prank(account3);
        simpleERC20.burnFrom(account1, value);
        
        assertEq(simpleERC20.balanceOf(account1), 0);
    }
}