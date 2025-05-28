// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Gaming Tournament Platform
 * @dev A decentralized platform for organizing and managing gaming tournaments
 * @author Gaming Tournament Platform Team
 */
contract Project {
    // Tournament structure
    struct Tournament {
        uint256 id;
        string name;
        address organizer;
        uint256 entryFee;
        uint256 prizePool;
        uint256 maxParticipants;
        uint256 currentParticipants;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool isCompleted;
        address winner;
        mapping(address => bool) participants;
        address[] participantList;
    }

    // State variables
    mapping(uint256 => Tournament) public tournaments;
    mapping(address => uint256[]) public userTournaments;
    uint256 public tournamentCounter;
    uint256 public platformFeePercentage = 5; // 5% platform fee
    address public owner;

    // Events
    event TournamentCreated(
        uint256 indexed tournamentId,
        string name,
        address indexed organizer,
        uint256 entryFee,
        uint256 maxParticipants
    );
    
    event PlayerRegistered(
        uint256 indexed tournamentId,
        address indexed player
    );
    
    event TournamentCompleted(
        uint256 indexed tournamentId,
        address indexed winner,
        uint256 prizeAmount
    );

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier tournamentExists(uint256 _tournamentId) {
        require(_tournamentId < tournamentCounter, "Tournament does not exist");
        _;
    }

    modifier onlyOrganizer(uint256 _tournamentId) {
        require(
            tournaments[_tournamentId].organizer == msg.sender,
            "Only tournament organizer can call this function"
        );
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Core Function 1: Create a new gaming tournament
     * @param _name Tournament name
     * @param _entryFee Entry fee in wei
     * @param _maxParticipants Maximum number of participants
     * @param _durationInHours Tournament duration in hours
     */
    function createTournament(
        string memory _name,
        uint256 _entryFee,
        uint256 _maxParticipants,
        uint256 _durationInHours
    ) external {
        require(bytes(_name).length > 0, "Tournament name cannot be empty");
        require(_maxParticipants > 1, "Must allow at least 2 participants");
        require(_durationInHours > 0, "Duration must be positive");

        uint256 tournamentId = tournamentCounter;
        Tournament storage newTournament = tournaments[tournamentId];
        
        newTournament.id = tournamentId;
        newTournament.name = _name;
        newTournament.organizer = msg.sender;
        newTournament.entryFee = _entryFee;
        newTournament.prizePool = 0;
        newTournament.maxParticipants = _maxParticipants;
        newTournament.currentParticipants = 0;
        newTournament.startTime = block.timestamp;
        newTournament.endTime = block.timestamp + (_durationInHours * 1 hours);
        newTournament.isActive = true;
        newTournament.isCompleted = false;

        tournamentCounter++;

        emit TournamentCreated(
            tournamentId,
            _name,
            msg.sender,
            _entryFee,
            _maxParticipants
        );
    }

    /**
     * @dev Core Function 2: Register a player for a tournament
     * @param _tournamentId ID of the tournament to join
     */
    function registerForTournament(uint256 _tournamentId) 
        external 
        payable 
        tournamentExists(_tournamentId) 
    {
        Tournament storage tournament = tournaments[_tournamentId];
        
        require(tournament.isActive, "Tournament is not active");
        require(!tournament.isCompleted, "Tournament is already completed");
        require(block.timestamp < tournament.endTime, "Tournament registration has ended");
        require(
            tournament.currentParticipants < tournament.maxParticipants,
            "Tournament is full"
        );
        require(
            !tournament.participants[msg.sender],
            "Already registered for this tournament"
        );
        require(msg.value == tournament.entryFee, "Incorrect entry fee");

        // Register the player
        tournament.participants[msg.sender] = true;
        tournament.participantList.push(msg.sender);
        tournament.currentParticipants++;
        tournament.prizePool += msg.value;

        // Track user's tournaments
        userTournaments[msg.sender].push(_tournamentId);

        emit PlayerRegistered(_tournamentId, msg.sender);
    }

    /**
     * @dev Core Function 3: Declare tournament winner and distribute prizes
     * @param _tournamentId ID of the tournament
     * @param _winner Address of the winning player
     */
    function declareTournamentWinner(uint256 _tournamentId, address _winner)
        external
        tournamentExists(_tournamentId)
        onlyOrganizer(_tournamentId)
    {
        Tournament storage tournament = tournaments[_tournamentId];
        
        require(tournament.isActive, "Tournament is not active");
        require(!tournament.isCompleted, "Tournament already completed");
        require(
            tournament.participants[_winner],
            "Winner must be a registered participant"
        );
        require(tournament.currentParticipants > 0, "No participants in tournament");

        // Calculate prize distribution
        uint256 platformFee = (tournament.prizePool * platformFeePercentage) / 100;
        uint256 winnerPrize = tournament.prizePool - platformFee;

        // Update tournament state
        tournament.winner = _winner;
        tournament.isCompleted = true;
        tournament.isActive = false;

        // Transfer prizes
        payable(_winner).transfer(winnerPrize);
        payable(owner).transfer(platformFee);

        emit TournamentCompleted(_tournamentId, _winner, winnerPrize);
    }

    // View functions
    function getTournamentDetails(uint256 _tournamentId)
        external
        view
        tournamentExists(_tournamentId)
        returns (
            string memory name,
            address organizer,
            uint256 entryFee,
            uint256 prizePool,
            uint256 maxParticipants,
            uint256 currentParticipants,
            uint256 startTime,
            uint256 endTime,
            bool isActive,
            bool isCompleted,
            address winner
        )
    {
        Tournament storage tournament = tournaments[_tournamentId];
        return (
            tournament.name,
            tournament.organizer,
            tournament.entryFee,
            tournament.prizePool,
            tournament.maxParticipants,
            tournament.currentParticipants,
            tournament.startTime,
            tournament.endTime,
            tournament.isActive,
            tournament.isCompleted,
            tournament.winner
        );
    }

    function getTournamentParticipants(uint256 _tournamentId)
        external
        view
        tournamentExists(_tournamentId)
        returns (address[] memory)
    {
        return tournaments[_tournamentId].participantList;
    }

    function getUserTournaments(address _user)
        external
        view
        returns (uint256[] memory)
    {
        return userTournaments[_user];
    }

    function isPlayerRegistered(uint256 _tournamentId, address _player)
        external
        view
        tournamentExists(_tournamentId)
        returns (bool)
    {
        return tournaments[_tournamentId].participants[_player];
    }

    // Owner functions
    function updatePlatformFee(uint256 _newFeePercentage) external onlyOwner {
        require(_newFeePercentage <= 10, "Platform fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    // Receive function to accept Ether
    receive() external payable {}
}
