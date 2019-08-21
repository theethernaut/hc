import "@aragon/os/contracts/apps/AragonApp.sol";

import "@aragon/os/contracts/lib/math/SafeMath.sol";

import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";


contract HCVoting is AragonApp {
    using SafeMath for uint256;

    /*
     * Errors
     */

    string internal constant ERROR_PROPOSAL_DOES_NOT_EXIST = "HCVOTING_PROPOSAL_DOES_NOT_EXIST";
    string internal constant ERROR_VOTE_ALREADY_CASTED     = "HCVOTING_VOTE_ALREADY_CASTED";
    string internal constant ERROR_NO_VOTING_POWER         = "HCVOTING_NO_VOTING_POWER";

    /*
     * Events
     */

    event ProposalCreated(uint256 proposalId, address creator, string metadata);
    event VoteCasted(uint256 proposalId, address voter, bool supports);

    /*
     * Properties
     */

    enum Vote { Absent, Yea, Nay }

    struct Proposal {
        uint256 totalYeas;
        uint256 totalNays;
        mapping (address => Vote) votes;
    }

    mapping (uint256 => Proposal) proposals;
    uint256 public numProposals;

    MiniMeToken public voteToken;

    /*
     * Init
     */

    function initialize(MiniMeToken _voteToken) public onlyInit {
        initialized();

        voteToken = _voteToken;
    }

    /*
     * Public
     */

    function createProposal(string _metadata) public {
        emit ProposalCreated(numProposals, msg.sender, _metadata);
        numProposals++;
    }

    function vote(uint256 _proposalId, bool _supports) public {
        Proposal storage proposal_ = _getProposal(_proposalId);

        uint256 userVotingPower = voteToken.balanceOf(msg.sender);
        require(userVotingPower > 0, ERROR_NO_VOTING_POWER);

        // Reject redundant votes.
        Vote previousVote = proposal_.votes[msg.sender];
        require(
            previousVote == Vote.Absent || !(previousVote == Vote.Yea && _supports || previousVote == Vote.Nay && !_supports),
            ERROR_VOTE_ALREADY_CASTED
        );

        // Update yea/nay count.
        if (previousVote == Vote.Absent) {
            if (_supports) {
                proposal_.totalYeas = proposal_.totalYeas.add(userVotingPower);
            } else {
                proposal_.totalNays = proposal_.totalNays.add(userVotingPower);
            }
        } else {
            if (previousVote == Vote.Yea && !_supports) {
                proposal_.totalYeas = proposal_.totalYeas.sub(userVotingPower);
                proposal_.totalNays = proposal_.totalNays.add(userVotingPower);
            } else if (previousVote == Vote.Nay && _supports) {
                proposal_.totalNays = proposal_.totalNays.sub(userVotingPower);
                proposal_.totalYeas = proposal_.totalYeas.add(userVotingPower);
            }
        }

        // Update vote record for the sender.
        proposal_.votes[msg.sender] = _supports ? Vote.Yea : Vote.Nay;

        emit VoteCasted(_proposalId, msg.sender, _supports);
    }

    /*
     * Getters
     */

    function getVote(uint256 _proposalId, address _user) public view returns (Vote) {
        Proposal storage proposal_ = _getProposal(_proposalId);
        return proposal_.votes[_user];
    }

    function getProposalYeas(uint256 _proposalId) public view returns (uint256) {
        Proposal storage proposal_ = _getProposal(_proposalId);
        return proposal_.totalYeas;
    }

    function getProposalNays(uint256 _proposalId) public view returns (uint256) {
        Proposal storage proposal_ = _getProposal(_proposalId);
        return proposal_.totalNays;
    }

    /*
     * Internal
     */

    function _getProposal(uint256 _proposalId) internal view returns (Proposal storage) {
        require(_proposalId < numProposals, ERROR_PROPOSAL_DOES_NOT_EXIST);
        return proposals[_proposalId];
    }
}
