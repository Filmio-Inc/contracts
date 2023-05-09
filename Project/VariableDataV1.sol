pragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

contract VariableDataV1 {
    // struct for storing lock details
    struct LockDetails {
        string projectId;
        uint256 createdAt;
    }

    // mapping of project Id with lock details
    mapping(string => LockDetails) public projectLockDetails;

    // project Ids that have been created
    string[] internal projects;

    // struct for storing remark udated
    struct Update {
        string projectId;
        string remark;
        uint256 timestamp;
    }

    // mapping of project Id with update struct array
    mapping(string => Update[]) public projectUpdateDetails;

    // struct for storing Evaluation details
    struct EvaluateDetails {
        uint256 evaluationId;
        string questionIds;
        string projectId;
        uint256 rating;
        address account;
    }

    // mapping of project Id with Evaluation questions ids
    mapping(string => string) public projectEvaluationQuestions;

    // mapping of project Id with Evaluation struct
    mapping(string => EvaluateDetails) public projectEvaluation;

    // mapping of user to Evaluation struct
    mapping(address => EvaluateDetails[]) public userEvaluation;

    // mapping from evaluation Id to its index in its user evaluation array
    mapping(uint256 => uint256) public evaluationIndicies;

    // storing Rating details in struct
    struct RatingDetails {
        uint256 ratingId;
        address user;
        uint256 rating;
        bool reviewGiven;
        uint256 timestamp;
        string projectId;
    }

    // storing rating details w.r.t user address
    struct User {
        address user;
        string[] projectsRated;
        uint256[] ratingIds;
        mapping(string => uint256) projectRating;
    }

    // mapping of Rating Id w.r.t rating details
    mapping(uint256 => RatingDetails) public ratingDetails;

    // mapping of project Id w.r.t rating Ids array
    mapping(string => uint256[]) public ratingById;

    // mapping of user w.r.t to user struct details
    mapping(address => User) public userRatings;

    // rating Id counter
    uint256 public ratingId;

    // evaluation Id counter
    uint256 public evaluationId;

    // gap for future variables (upgrades)
    uint256[50] __gap;

    /**
     * @dev Emitted when new rating is created.
     */

    event RatingAdded(string indexed projectId, uint256 userRating, address givenBy);

    /**
     * @dev Emitted when rating is modified.
     */

    event RatingModified(string indexed projectId, uint256 userRating, address modifiedBy);

    /**
     * @dev Emitted when review is given.
     */

    event ReviewGiven(string indexed projectId, address givenBy);

    /**
     * @dev Emitted when evaluation is created.
     */

    event EvaluationCreated(
        uint256 indexed evaluationId,
        string indexed projectId,
        string questionIds,
        uint256 rating,
        address user
    );

    /**
     * @dev Emitted when evaluation is modified.
     */

    event EvaluationModified(
        uint256 indexed evaluationId,
        string indexed projectId,
        string questionIds,
        uint256 rating,
        address user
    );

    /**
     * @dev Emitted when new update is created.
     */

    event UpdateCreated(string indexed projectId, string remark, address createdBy);

    /**
     * @dev Emitted when new lock is created.
     */

    event LockCreated(string indexed projectId, address createdBy);

    /**
     * @dev Emitted when trusted forwarder address is modified.
     */

    event TrustedForwarderModified(address forwarder);

    /**
     * @dev Emitted when evaluation questions are set.
     */

    event EvaluationQuestionsSet(string indexed projectId, string questionIds);
}
