pragma solidity 0.7.5;
pragma abicoder v2;

contract MultiSigsContract{
    
    event logMessage(string message);
    
    modifier approversOnly {
        require(
            msg.sender == approver1
            || msg.sender == approver2
            || msg.sender == approver3,
            "Only approver addresses can approve transactions."
        );
        _;
    }
    
    struct Transaction {
        uint id;
        address from;
        address to;
        uint amount;
    }
    
    address approver1;
    address approver2;
    address approver3;
    Transaction[] transactions;
    mapping(uint => address[]) approbations;

    
    // specifying the other 2 approvers, the first being the contract initiator
    constructor(address _approver2, address _approver3){
        approver1 = msg.sender;
        approver2 = _approver2;
        approver3 = _approver3;
    }
    
    // Used by users to send a transaction to an address.
    function SendTo(address _to) public payable {
        
        require(msg.value > 0, "Amount must be at least 1 wei.");
        
        Transaction memory transaction = Transaction(
            transactions.length,
            msg.sender,
            _to,
            msg.value
        );
        transactions.push(transaction);
        
        emit logMessage("Transaction added.");
    }
    
    // Get infos of a specific transacton, pending or executed.
    function GetTransactionInfos(uint _index) public returns(Transaction memory tx, bool isExecuted){
        
        Transaction memory tx = transactions[_index];
        
        return (
            tx,
            TransactionIsExecuted(_index)
        );
    }
    
    // Get a list of pending txs. Could be used by the senders or approvers.
    function GetPendingTransactions() public returns (Transaction[] memory){
        
        Transaction[] memory txs = new Transaction[](transactions.length);
        uint counter = 0;
        for(uint i = 0; i < transactions.length; i++){
            if(TransactionIsExecuted(i) == false){
                txs[counter++] = transactions[i];
            }
        }
        
        return txs;
    }
    
    // Used by approvers to approve a tx. When 2 out of 3 approvers approved, the tx is executed.
    function ApproveTransaction(uint _index) public approversOnly returns(bool isExecuted){
        
        // add to tx approbations
        address[] memory txApprobations = approbations[_index];
        address currentApproverAddress = msg.sender;
        
        if(txApprovedByAddress(txApprobations, currentApproverAddress) == false){
            address[] memory appendedTxApprobations = AppendAddressToTxApprobations(_index, currentApproverAddress);
            approbations[_index] = appendedTxApprobations; // assign
            
            // execute tx if 2/3 approbations threshold is reached. Note : if more that 2 approvers is reached, the tx will NOT be executed again.
            if(appendedTxApprobations.length == 2){
                return ExecuteTransaction(_index);
            } else {
                emit logMessage("Tx approbation threshold not reached or tx already executed.");
                return false;
            }
            
            
        } else /* already approved by this address*/ {
            emit logMessage("Tx already approved.");
            return false;
        }
        
    }
    
    // For debugging 
    function GetBalance() public returns (uint balance){
        return address(this).balance;
    }
    
    // Add an address to the list of address so that we can update the approval status.
    function AppendAddressToTxApprobations(uint _index, address _address) private returns (address[] memory addresses){
        
        // clone existing values
        address[] memory txApprobations = approbations[_index];
        address[] memory arr = new address[](txApprobations.length + 1);
        for(uint i = 0; i < txApprobations.length; i++){
            arr[i] = txApprobations[i];
        }
        
        // append and return
        arr[txApprobations.length] = _address;
        
        return arr;
    }
    
    // Used to check if an address(approver) already approved this tx.
    function txApprovedByAddress(address[] memory txApprobations, address approverAddress) private returns (bool){
        for(uint i = 0; i < txApprobations.length; i++){
            if(txApprobations[i] == approverAddress){
                return true;
            } else {
                return false;
            }
        }
    }
    
    // Checks if the tx is already executed.
    function TransactionIsExecuted(uint _index) private returns(bool isExecuted){
        
        address[] memory txApprovers = approbations[_index]; // contains the addresses that approved this transaction
        if(txApprovers.length > 1){
            return true;
        } else {
            return false; // pending
        }
        
    }
    
    // Sends the tx funds to the destination.
    function ExecuteTransaction(uint _index) private returns(bool isExecuted){
        emit logMessage("Executing tx...");
        Transaction memory tx = transactions[_index];
        payable(tx.to).transfer(tx.amount);
        return true;
    }
    
}