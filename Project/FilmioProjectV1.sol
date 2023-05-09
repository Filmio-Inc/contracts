pragma solidity ^0.8.9;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC2771Recipient } from "@opengsn/contracts/src/ERC2771Recipient.sol";
import { OwnableUpgradeable, ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IFilmioProjectV1 } from "./IFilmioProjectV1.sol";
import { VariableDataV1 } from "./VariableDataV1.sol";

// SPDX-License-Identifier: MIT
contract FilmioProjectV1 is ERC2771Recipient, OwnableUpgradeable, IFilmioProjectV1, VariableDataV1 {
    // lock the implementation contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // Initialisation section

    function initialize(address _trustedForwarder) public initializer {
        require(_trustedForwarder != address(0), "FilmioProjectV1: trustedForwarder address is zero");

        __Ownable_init();
        _setTrustedForwarder(_trustedForwarder);
        ratingId = 1;
        evaluationId = 1;
    }

    //for changing trustedForwarder address
    function setTruestedForwarder(address _trustedForwarder) public onlyOwner {
        require(_trustedForwarder != address(0), "FilmioProjectV1: trustedForwarder address is zero");
        _setTrustedForwarder(_trustedForwarder);

        emit TrustedForwarderModified(_trustedForwarder);
    }

    /**
     * @dev sets the question ids for a project evaluation
     *
     * @param projectId project Id.
     * @param questionIds questions Ids in the format "{id_1}-{id_2}-...-{id_n}" e.g. "5-232-12"
     *
     * Requirements:
     * - only owner can set questions.
     *
     * Emits a {evaluationQuestionsSet} event.
     */
    function setEvaluationQuestions(string memory projectId, string memory questionIds) external onlyOwner {
        require(bytes(questionIds).length > 0, "FilmioProjectV1: questions are empty");

        projectEvaluationQuestions[projectId] = questionIds;

        emit EvaluationQuestionsSet(projectId, questionIds);
    }

    /**
     * @dev creates lock.
     *
     * @param projectId address.
     *
     * Requirements:
     * - only owner can create lock.
     *
     * Returns
     * - boolean.
     *
     * Emits a {lockCreated} event.
     */
    function createLock(string memory projectId) external {
        require(strlen(projectId) > 0, "FilmioProjectV1: projectId is empty");

        require(strlen(projectLockDetails[projectId].projectId) == 0, "Lock already created for this project");

        LockDetails memory newLock = LockDetails(projectId, block.timestamp);
        projectLockDetails[projectId] = newLock;
        projects.push(projectId);

        emit LockCreated(projectId, _msgSender());
    }

    /**
     * @dev create update for a project.
     *
     * @param projectId project Id.
     * @param remark remark.
     *
     * Requirements:
     * - Project Id must be created.
     *
     * Returns
     * - boolean.
     *
     * Emits a {updateCreated} event.
     */
    function createUpdate(string memory projectId, string memory remark) external {
        require(strlen(projectId) > 0, "FilmioProjectV1: projectId is empty");

        require(
            keccak256(abi.encodePacked((projectLockDetails[projectId].projectId))) ==
                keccak256(abi.encodePacked((projectId))),
            "FilmioProjectV1: Project does not exist"
        );

        Update memory newUpdate = Update(projectId, remark, block.timestamp);
        projectUpdateDetails[projectId].push(newUpdate);

        emit UpdateCreated(projectId, remark, _msgSender());
    }

    /**
     * @dev creates evaluation for a project.
     *
     * @param projectId project Id.
     * @param rating rating for all given questions
     *
     * Requirements:
     * - Project Id must be created.
     *
     * Returns
     * - boolean.
     *
     * Emits a {evaluationCreated} event.
     */
    function createEvaluation(string memory projectId, uint256 rating) external {
        require(strlen(projectId) > 0, "FilmioProjectV1: projectId is empty");

        require(
            keccak256(abi.encodePacked((projectLockDetails[projectId].projectId))) ==
                keccak256(abi.encodePacked((projectId))),
            "FilmioProjectV1: Project does not exist"
        );

        require(
            projectEvaluation[projectId].account == address(0),
            "FilmioProjectV1: Project is already evaluated by user"
        );

        require(
            strlen(projectEvaluationQuestions[projectId]) > 0,
            "FilmioProjectV1: Questions are not set for this project yet"
        );

        require(
            validateEvaluationQuestions(projectEvaluationQuestions[projectId], rating),
            "FilmioProjectV1: Questions Ids and/or rating are not valid/compatible"
        );

        EvaluateDetails memory evaluation = EvaluateDetails(
            evaluationId,
            projectEvaluationQuestions[projectId],
            projectId,
            rating,
            _msgSender()
        );
        projectEvaluation[projectId] = evaluation;

        EvaluateDetails memory userEval = EvaluateDetails(
            evaluationId,
            projectEvaluationQuestions[projectId],
            projectId,
            rating,
            _msgSender()
        );

        userEvaluation[_msgSender()].push(userEval);

        evaluationIndicies[evaluationId] = userEvaluation[_msgSender()].length;

        evaluationId += 1;

        emit EvaluationCreated(
            evaluationId - 1,
            projectId,
            projectEvaluationQuestions[projectId],
            rating,
            _msgSender()
        );
    }

    /**
     * @dev modifies evaluation for a project.
     *
     * @param projectId project Id.
     * @param rating new rating for all given questions
     *
     * Requirements:
     * - Project Id must be created.
     *
     * Returns
     * - boolean.
     *
     * Emits a {evaluationModified} event.
     */
    function modifyEvaluation(string memory projectId, uint256 rating) external {
        require(strlen(projectId) > 0, "FilmioProjectV1: projectId is empty");

        require(
            keccak256(abi.encodePacked((projectLockDetails[projectId].projectId))) ==
                keccak256(abi.encodePacked((projectId))),
            "FilmioProjectV1: Project does not exist"
        );

        require(
            projectEvaluation[projectId].rating != rating,
            "FilmioProjectV1: Provided rating is the same as previous"
        );

        require(
            strlen(projectEvaluationQuestions[projectId]) > 0,
            "FilmioProjectV1: Questions are not set for this project yet"
        );

        require(
            validateEvaluationQuestions(projectEvaluationQuestions[projectId], rating),
            "FilmioProjectV1: Questions Ids and/or rating are not valid/compatible"
        );

        uint256 _evaluationId = projectEvaluation[projectId].evaluationId;

        uint256 evaludationIndex = evaluationIndicies[_evaluationId];

        require(evaludationIndex > 0, "FilmioProjectV1: Evaluation does not exist");

        evaludationIndex -= 1;

        require(
            evaludationIndex < userEvaluation[_msgSender()].length,
            "FilmioProjectV1: Not allowed to modify this evaluation or evaluation does not exist"
        );

        require(
            keccak256(abi.encodePacked((userEvaluation[_msgSender()][evaludationIndex].projectId))) ==
                keccak256(abi.encodePacked((projectId))),
            "FilmioProjectV1: User is not allowed to modify this evaluation"
        );

        require(
            keccak256(abi.encodePacked((projectId))) ==
                keccak256(abi.encodePacked((projectEvaluation[projectId].projectId))),
            "FilmioProjectV1: No data found"
        );

        EvaluateDetails memory modifiedEvaluation = EvaluateDetails(
            _evaluationId,
            projectEvaluationQuestions[projectId],
            projectId,
            rating,
            _msgSender()
        );

        projectEvaluation[projectId] = modifiedEvaluation;
        userEvaluation[_msgSender()][evaludationIndex] = modifiedEvaluation;

        emit EvaluationModified(_evaluationId, projectId, projectEvaluationQuestions[projectId], rating, _msgSender());
    }

    /**
     * @dev  create rating for a project.
     *
     * @param projectId project Id.
     * @param userRating rating (1 to 5)
     *
     * Requirements:
     * - Project Id must be created.
     *
     * Returns
     * - boolean.
     *
     * Emits a {ratingAdded} event.
     */

    function createRating(string memory projectId, uint256 userRating) external {
        require(strlen(projectId) > 0, "FilmioProjectV1: projectId is empty");

        require(
            keccak256(abi.encodePacked((projectLockDetails[projectId].projectId))) ==
                keccak256(abi.encodePacked((projectId))),
            "FilmioProjectV1: Project does not exist"
        );

        require(userRating >= 1 && userRating <= 10, "FilmioProjectV1: Rating needs to be between 1 to 10");

        require(
            userRatings[_msgSender()].projectRating[projectId] == 0,
            "FilmioProjectV1: The project has already been rated by the User"
        );

        RatingDetails memory newRating = RatingDetails(
            ratingId,
            _msgSender(),
            userRating,
            false,
            block.timestamp,
            projectId
        );

        ratingDetails[ratingId] = newRating;
        ratingById[projectId].push(ratingId);

        userRatings[_msgSender()].projectRating[projectId] = ratingId;
        userRatings[_msgSender()].ratingIds.push(ratingId);
        userRatings[_msgSender()].projectsRated.push(projectId);
        userRatings[_msgSender()].user = _msgSender();

        ratingId += 1;
        emit RatingAdded(projectId, userRating, _msgSender());
    }

    /**
     * @dev modify rating for a project.
     *
     * @param projectId project Id.
     * @param userRating rating (1 to 5)
     *
     * Requirements:
     * - Project Id must be created.
     *
     * Returns
     * - boolean.
     *
     * Emits a {ratingModified} event.
     */
    function modifyRating(string memory projectId, uint256 userRating) external {
        require(strlen(projectId) > 0, "FilmioProjectV1: projectId is empty");

        require(
            keccak256(abi.encodePacked((projectId))) ==
                keccak256(abi.encodePacked((projectLockDetails[projectId].projectId))),
            "FilmioProjectV1: Project does not exist"
        );

        require(userRating >= 1 && userRating <= 10, "FilmioProjectV1: Rating needs to be between 1 to 10");
        require(
            userRatings[_msgSender()].projectRating[projectId] != 0,
            "FilmioProjectV1: User has not yet rated this Project"
        );

        uint256 updateRatingIds = userRatings[_msgSender()].projectRating[projectId];

        require(ratingDetails[updateRatingIds].rating != userRating, "FilmioProjectV1: Rating is the same as previous");
        require(
            ratingDetails[updateRatingIds].reviewGiven == false,
            "FilmioProjectV1: Review has been given, cannot modify rating"
        );

        ratingDetails[updateRatingIds].rating = userRating;
        ratingDetails[updateRatingIds].timestamp = block.timestamp;

        emit RatingModified(projectId, userRating, _msgSender());
    }

    /**
     * @dev add review for a project.
     *
     * @param projectId project Id.
     *
     * Requirements:
     * - Project Id must be created.
     *
     * Returns
     * - boolean.
     *
     * Emits a {reviewGiven} event.
     */

    function addReview(string memory projectId) external {
        require(strlen(projectId) > 0, "FilmioProjectV1: projectId is empty");

        require(
            keccak256(abi.encodePacked((projectLockDetails[projectId].projectId))) ==
                keccak256(abi.encodePacked((projectId))),
            "FilmioProjectV1: Project does not exist"
        );

        uint256 ratingIndex = userRatings[_msgSender()].projectRating[projectId];

        require(ratingDetails[ratingIndex].reviewGiven == false, "FilmioProjectV1: Review already given");
        require(ratingIndex > 0, "FilmioProjectV1: Rating must be given before review");

        ratingDetails[ratingIndex].reviewGiven = true;

        emit ReviewGiven(projectId, _msgSender());
    }

    //This function returns rating details for a prticular project
    /**
     * @dev returns rating details for a prticular project.
     *
     * @param projectId project Id.
     *
     * Requirements:
     * - Project Id must be created.
     *
     * Returns
     * - rating details
     */
    function ratingOfProject(string memory projectId) external view returns (RatingDetails[] memory) {
        require(strlen(projectId) > 0, "FilmioProjectV1: projectId is empty");

        require(
            keccak256(abi.encodePacked((projectId))) ==
                keccak256(abi.encodePacked((projectLockDetails[projectId].projectId))),
            "FilmioProjectV1: Project does not exist"
        );

        uint256[] memory projectRatingIdss = ratingById[projectId];
        return getRatingDetails(projectRatingIdss);
    }

    /**
     * @dev  returns rating details given by user.
     *
     * @param user address.
     *
     * Requirements:
     * - Project Id must be created.
     *
     * Returns
     * - rating details
     */
    function ratingByUser(address user) external view returns (RatingDetails[] memory) {
        uint256[] memory projectRatingIdss = userRatings[user].ratingIds;
        return getRatingDetails(projectRatingIdss);
    }

    /**
     * @dev private function to get rating details.
     */
    function getRatingDetails(uint256[] memory _ratingNumbers) private view returns (RatingDetails[] memory) {
        RatingDetails[] memory ratings = new RatingDetails[](_ratingNumbers.length);
        for (uint i = 0; i < _ratingNumbers.length; i++) {
            RatingDetails memory rating = ratingDetails[_ratingNumbers[i]];
            ratings[i] = rating;
        }
        return (ratings);
    }

    /**
     * @dev returns all project Ids.
     *
     * Returns
     * - All project Ids
     */
    function getAllProjectID() external view returns (string[] memory) {
        return (projects);
    }

    /**
     * @dev checks if a given project id exists
     *
     * @param projectId project Id.
     *
     * Returns
     * - True/False
     */
    function doesProjectExist(string memory projectId) external view returns (bool) {
        return
            keccak256(abi.encodePacked((projectId))) ==
            keccak256(abi.encodePacked((projectLockDetails[projectId].projectId))) &&
            strlen(projectId) != 0;
    }

    /*
     * @dev This function is used to validate the questions Ids and rating
     *
     * @param questionsIds questions Ids
     * @param rating rating
     *
     * Returns
     * - True/False
     */
    function validateEvaluationQuestions(string memory questionsIds, uint256 rating) internal pure returns (bool) {
        string memory ratingString = Strings.toString(rating);

        uint numQuestions = 1;
        uint questionsIdsLength = strlen(questionsIds);

        if (questionsIdsLength == 0) {
            return false;
        }

        for (uint i; i < questionsIdsLength; i++) {
            bytes1 char = bytes(questionsIds)[i];

            // checks if all character are either numbers or the character '-'
            if (!((char >= 0x30 && char <= 0x39) || char == 0x2d)) {
                return false;
            }

            if (char == 0x2d) {
                // check for '-'
                numQuestions += 1;
            }
        }

        if (strlen(ratingString) != numQuestions) {
            return false;
        }

        return true;
    }

    // This function is used to get the length of a string
    function strlen(string memory s) internal pure returns (uint256) {
        uint256 len;
        uint256 i = 0;
        uint256 byteLength = bytes(s).length;
        for (len = 0; i < byteLength; len++) {
            bytes1 b = bytes(s)[i];
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }

    // These two are internal functions, they are required for eip 2771
    // when openzepplin ownable or upgrade functionalities are used

    function _msgSender() internal view override(ContextUpgradeable, ERC2771Recipient) returns (address sender) {
        sender = ERC2771Recipient._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, ERC2771Recipient) returns (bytes calldata) {
        return ERC2771Recipient._msgData();
    }
}
