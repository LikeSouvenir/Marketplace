// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Simple ERC-20
/// @author GitHub.com/LikeSouvenir
/// @dev Interface of the ERC-20 standard with increaseAllowance, decreaseAllowance and burnFrom
contract SimpleERC20 {
    uint8 constant _decimals = 18;            
    string _name;                                   
    string _symbol;                               
    uint _totalSupply;                         

    mapping (address => uint) _balances;       
    mapping(address owner => mapping(address spender => uint value)) _allowances;

    address immutable _owner;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed from, address indexed to, uint value);

    /// @dev Throws if called by any account other than the owner.
    modifier onlyOwner() {
        require(msg.sender == _owner, "only Owner");
        _;
    }

    /// @dev Sets the values for {name} and {symbol}. Make owner to msg.sender
    constructor(string memory name_, string memory symbol_) {
        _owner = msg.sender;
        _name = name_;
        _symbol = symbol_;
    }

    /// @dev Returns the decimals places of the token.
    function decimals() external virtual view returns(uint8) {
        return _decimals;
    }

    /// @dev Returns the symbol of the token.
    function name() external virtual view returns(string memory) {
        return _name;
    }

    /// @dev Returns the name of the token.
    function symbol() external virtual view returns(string memory) {
        return _symbol;
    }

    /// @dev Returns the total amount of tokens in existence.
    function totalSupply() external virtual view returns(uint) {
        return _totalSupply;
    }

    /// @dev Returns the amount of tokens owned by `account`.
    function balanceOf(address account) external virtual view returns(uint) {
        return _balances[account];
    }

    /// @dev Moves `value` amount of tokens from the caller's account to `to`.
    function transfer(address to, uint value) external virtual returns(bool) {
        _transfer(msg.sender, to, value);
        emit Transfer(msg.sender, to, value);

        return true;
    }

    /// @dev Moves `value` amount of tokens from `from` to `to` using the allowance mechanism.
    function transferFrom(address from, address to, uint value) external virtual returns(bool) {
        uint currentValue = _allowances[from][msg.sender];
        require(currentValue >= value, "not enough allowance");
        _transfer(from, to, value);
        _approve(from, msg.sender, currentValue - value, true);
        emit Transfer(from, to, value);
        
        return true;
    }

    function _transfer(address from, address to, uint value) internal virtual {
        require(from != address(0), "bad from");
        require(to != address(0), "bad to");
        _update(from, to, value);
    }

    /// @dev Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner`
    function allowance(address owner, address spender) external virtual view returns(uint amount) {
        return _allowances[owner][spender];
    }

    /// @dev Increases the allowance of `spender` by `value`.
    function increaseAllowance(address spender, uint value) external virtual returns(bool){
        uint currentValue = _allowances[msg.sender][spender]; 

        _approve(msg.sender, spender, currentValue + value);
        return true;
    }
    
    /// @dev Decreases the allowance of `spender` by `value`.
    function decreaseAllowance(address spender, uint value) external virtual returns(bool){
        uint currentValue = _allowances[msg.sender][spender];
        require(currentValue >= value, "incorrect value");

        _approve(msg.sender, spender, currentValue - value);
        return true;
    }

    /// @dev Sets `value` as the allowance of `spender` over the caller's tokens.
    function approve(address spender, uint value) external virtual returns(bool){
        _approve(msg.sender, spender, value);
        return true;
    }

    function _approve(address owner, address spender, uint value) internal virtual {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint value, bool emitEvent) internal virtual {
        require(owner != address(0), "bad owner");
        require(spender != address(0), "bad spender");

        _allowances[owner][spender] = value;

        if(emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /// @dev Mints `value` amount of tokens to `to`. Only callable by owner.
    function mint(address to, uint value) public virtual onlyOwner{
        _update(address(0), to, value);
    }

    /// @dev Destroys `value` amount of tokens from the caller's account.
    function burn(uint value) external virtual returns(bool){
        _burn(msg.sender, value);
        return true;
    }

    /// @dev Destroys `value` amount of tokens from `from` using allowance.
    function burnFrom(address from, uint value) external virtual returns(bool){
        uint currentValue = _allowances[from][msg.sender];
        require(currentValue >= value, "not enough allowance");
        _burn(from, value);
        _approve(from, msg.sender, currentValue - value, true);
        return true;
    }

    function _burn(address from, uint value ) internal virtual {
        _update(from, address(0), value);
    }

    function _update(address from, address to, uint value) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            require(_balances[from] >= value, "not enough");
            _balances[from] -= value;
        }
    
        if (to == address(0)) {
            _totalSupply -= value;
        } else {
            _balances[to] += value;
        }
    }
}