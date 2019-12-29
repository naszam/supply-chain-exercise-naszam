pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/SupplyChain.sol";
import "./Proxy.sol";

contract TestSupplyChain {

    // Test for failing conditions in this contracts:
    // https://truffleframework.com/tutorials/testing-for-throws-in-solidity-tests

    uint public initialBalance = 1 ether;
    enum State { ForSale, Sold, Shipped, Received }

    SupplyChain public chain;
    Proxy public sellerProxy;
    Proxy public buyerProxy;
    Proxy public randomProxy;

    string itemName = "testItem";
    uint256 itemPrice = 3;
    uint256 itemSku = 0;

    // allow contract to receive ether
    function () external payable {}

    function beforeEach() public {

	// contract to test
        chain = new SupplyChain();
        sellerProxy = new Proxy(chain);
        buyerProxy = new Proxy(chain);
        randomProxy = new Proxy(chain);

	// seed buyers with some funds (in WEI)
    	uint256 seedValue = itemPrice + 1;
        address(buyerProxy).transfer(seedValue);

	// seed known item to set contract to 'for-sale'
	sellerProxy.placeItemForSale(itemName, itemPrice);
    }

    function getItemState(uint256 _sku)
            public view
            returns (uint256)
        {
            string memory name;
            uint sku;
            uint price;
            uint state;
            address seller;
            address buyer;

            (name, sku, price, state, seller, buyer) = chain.fetchItem(_sku);
            return state;
        }

    // buyItem
    // test for failure if user does not send enough funds
    function testForFailureIfUserDoesNotSendEnoughFunds() public {

        uint offer = itemPrice - 1;
        // try to buy item with lower funds
        bool result = buyerProxy.purchaseItem(itemSku, offer);
        Assert.isFalse(result, "Insufficient amount paid for item");

        // verify the item state
        Assert.equal(getItemState(itemSku), uint256(State.ForSale), "Item should be marked as ForSale");
    }
    // buyItem
    // test for purchasing an item that is not for Sale
    function testPurchasingItemNotForSale() public {

	// buy item
        uint offer = itemPrice;
        bool result = buyerProxy.purchaseItem(itemSku, offer);
        Assert.isTrue(result, "Paid the correct price");

        // item is purchased so the state should be 'ForSale'
        Assert.notEqual(getItemState(itemSku), uint256(State.ForSale), "Item should not be marked as ForSale");

	// buy item that is not for Sale
	result = buyerProxy.purchaseItem(itemSku, offer);
	Assert.isFalse(result, "Buyer should not be able to buy an item not marked as ForSale");
    }
    // shipItem
    // test for calls that are made not by the seller
    function testForCallsMadeNotBySeller() public {

      // buy item	    
      uint offer = itemPrice;
      bool result = buyerProxy.purchaseItem(itemSku, offer);
      Assert.isTrue(result, "Paid the correct price");

      // try to call shipItem with a random address
      result = randomProxy.shipItem(itemSku);
      Assert.isFalse(result, "Non seller can't ship");

      // check the state of item after buying it
      Assert.equal(getItemState(itemSku), uint256(State.Sold), "Item should remain Sold");
    }
    
    // shipItem
    // test for trying to ship an item that is not marked as Sold
    function testTryingShipItemNotMarkedSold() public {

      // try to ship the item
      bool result = sellerProxy.shipItem(itemSku);
      Assert.isFalse(result, "Seller should not be allowed to ship");
    }

    // receiveItem
    // test calling the function from an address that is not the buyer
    function testCallingReceiveFunctionFromAddressNotBuyer() public {
      
      // buy Item
      uint offer = itemPrice;
      bool result = buyerProxy.purchaseItem(itemSku, offer);
      Assert.isTrue(result, "Paid the correct price");
      
      // ship Item
      result = sellerProxy.shipItem(itemSku);
      Assert.isTrue(result, "Seller can ship item that was marked as Sold");
      
      // call receive function from a random address
      result = randomProxy.receiveItem(itemSku);
      Assert.isFalse(result, "Only buyer can receive an item");

      // verify state is Shipped
      Assert.equal(getItemState(itemSku), uint256(State.Shipped), "Item should remain Shipped");
    }
    // test calling the function on an item not marked Shipped
    function testCallingRecieveFunctionItemNotMarkedShipped() public {
      
      // buy Item
      uint offer = itemPrice;
      bool result = buyerProxy.purchaseItem(itemSku, offer);
      Assert.isTrue(result, "Paid the correct price");

      // try to recieve item before it is shipped
      result = buyerProxy.receiveItem(itemSku);
      Assert.isFalse(result, "buyer should not be able to receive an item marked as Sold");

      // the state of the item shold not be Shipped
      Assert.equal(getItemState(itemSku), uint256(State.Sold), "Item should be marked as Sold");
    }
}
