// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Crowdfunding Platform
 * @dev A smart contract for creating and managing crowdfunding campaigns
 * @author Your Name
 */
contract Project {
    
    // Struct to represent a crowdfunding campaign
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 amountRaised;
        bool withdrawn;
        mapping(address => uint256) contributions;
        address[] contributors;
    }
    
    // State variables
    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCount;
    uint256 public platformFee = 25; // 2.5% platform fee (in basis points)
    address public platformOwner;
    
    // Events
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goal,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );
    
    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    // Modifiers
    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this");
        _;
    }
    
    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCount, "Campaign does not exist");
        _;
    }
    
    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(msg.sender == campaigns[_campaignId].creator, "Only campaign creator can call this");
        _;
    }
    
    constructor() {
        platformOwner = msg.sender;
    }
    
    /**
     * @dev Core Function 1: Create a new crowdfunding campaign
     * @param _title Title of the campaign
     * @param _description Description of the campaign
     * @param _goal Funding goal in wei
     * @param _durationInDays Campaign duration in days
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _durationInDays
    ) external {
        require(_goal > 0, "Goal must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);
        
        Campaign storage newCampaign = campaigns[campaignCount];
        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goal = _goal;
        newCampaign.deadline = deadline;
        newCampaign.amountRaised = 0;
        newCampaign.withdrawn = false;
        
        emit CampaignCreated(campaignCount, msg.sender, _title, _goal, deadline);
        campaignCount++;
    }
    
    /**
     * @dev Core Function 2: Contribute to a campaign
     * @param _campaignId ID of the campaign to contribute to
     */
    function contribute(uint256 _campaignId) external payable campaignExists(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(msg.value > 0, "Contribution must be greater than 0");
        require(msg.sender != campaign.creator, "Creator cannot contribute to own campaign");
        
        // If this is the first contribution from this address, add to contributors array
        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }
        
        campaign.contributions[msg.sender] += msg.value;
        campaign.amountRaised += msg.value;
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }
    
    /**
     * @dev Core Function 3: Withdraw funds or get refund
     * @param _campaignId ID of the campaign
     */
    function withdrawOrRefund(uint256 _campaignId) external campaignExists(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(block.timestamp >= campaign.deadline, "Campaign is still active");
        
        if (msg.sender == campaign.creator) {
            // Creator withdrawal
            require(!campaign.withdrawn, "Funds already withdrawn");
            require(campaign.amountRaised >= campaign.goal, "Campaign did not reach goal");
            
            campaign.withdrawn = true;
            
            // Calculate platform fee
            uint256 fee = (campaign.amountRaised * platformFee) / 1000;
            uint256 creatorAmount = campaign.amountRaised - fee;
            
            // Transfer fee to platform owner
            if (fee > 0) {
                payable(platformOwner).transfer(fee);
            }
            
            // Transfer remaining amount to creator
            campaign.creator.transfer(creatorAmount);
            
            emit FundsWithdrawn(_campaignId, msg.sender, creatorAmount);
            
        } else {
            // Contributor refund (only if campaign failed)
            require(campaign.amountRaised < campaign.goal, "Campaign was successful, no refunds");
            
            uint256 contributedAmount = campaign.contributions[msg.sender];
            require(contributedAmount > 0, "No contributions found");
            
            campaign.contributions[msg.sender] = 0;
            campaign.amountRaised -= contributedAmount;
            
            payable(msg.sender).transfer(contributedAmount);
            
            emit RefundIssued(_campaignId, msg.sender, contributedAmount);
        }
    }
    
    // View functions
    function getCampaign(uint256 _campaignId) external view campaignExists(_campaignId) returns (
        address creator,
        string memory title,
        string memory description,
        uint256 goal,
        uint256 deadline,
        uint256 amountRaised,
        bool withdrawn,
        bool isActive,
        bool goalReached
    ) {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goal,
            campaign.deadline,
            campaign.amountRaised,
            campaign.withdrawn,
            block.timestamp < campaign.deadline,
            campaign.amountRaised >= campaign.goal
        );
    }
    
    function getContribution(uint256 _campaignId, address _contributor) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (uint256) 
    {
        return campaigns[_campaignId].contributions[_contributor];
    }
    
    function getCampaignContributors(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (address[] memory) 
    {
        return campaigns[_campaignId].contributors;
    }
    
    // Platform management functions
    function updatePlatformFee(uint256 _newFee) external onlyPlatformOwner {
        require(_newFee <= 100, "Fee cannot exceed 10%"); // Max 10% fee
        platformFee = _newFee;
    }
    
    function transferOwnership(address _newOwner) external onlyPlatformOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        platformOwner = _newOwner;
    }
}
