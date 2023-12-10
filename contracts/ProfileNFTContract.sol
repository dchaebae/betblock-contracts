// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";

contract ProfileNFTContract is ERC721, Pausable, FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;
    uint256 private _tokenIdCounter;

    // metadata of the NFT
    struct NFTMetadata {
        string name;
        string description;
        string imageCID;
        string tokenURI;
        uint256 createdAt;
        uint256 updatedAt;
    }
    // map tokenId to tokenMetadata
    mapping(uint256 => NFTMetadata) private _tokenMetadata;

    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    error UnexpectedRequestID(bytes32 requestId);
    // Response event
    event FunctionsResponse(bytes32 indexed requestId, bytes response, bytes err);

    // event for metadata being updated by the owner! backdoor for the contract owner :)
    event MetadataUpdated(uint256 indexed tokenId, string name, string description, string image);

    constructor(
        address router
    ) FunctionsClient(router) ConfirmedOwner(msg.sender) ERC721("Betblock Bio", "BBB") {}

    function _setTokenMetadata(uint256 tokenId, string memory imageCID, string memory name, string memory description, string memory tokenURI) private {
        NFTMetadata storage metadata = _tokenMetadata[tokenId];
        metadata.name = name;
        metadata.imageCID = imageCID;
        metadata.description = description;
        metadata.tokenURI = tokenURI;
        metadata.updatedAt = block.timestamp;
         
        if (metadata.createdAt == 0) {
            metadata.createdAt = block.timestamp;
        } 
        emit MetadataUpdated(tokenId, name, description, tokenURI);
    }

    // Update Token metadata if contract owner invokes
    function updateTokenMetadata(
        uint256 tokenId,
        string memory cid,
        string memory name,
        string memory description,
        string memory image
    ) public onlyOwner {
        // require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Only token owner can update metadata");
        _setTokenMetadata(tokenId, cid, name, description, image);
    }

    // get token metadata given tokenId
    function getTokenMetadata(uint256 tokenId) public view returns (NFTMetadata memory) {
        // require(_exists(tokenId), "Token does not exist");
        return _tokenMetadata[tokenId];
    }

    // mint requests is received, source function to generate AI image
    function mintRequest(
        string memory source,
        bytes memory encryptedSecretsUrl,
        string[] memory args,
        uint64 subscriptionId,
        uint32 gasLimit,
        bytes32 donID
    ) public returns (bytes32 requestId) {
        // prevent multiple mint requests
        require(balanceOf(msg.sender) == 0, "Address already owns an NFT");

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);
        req.addSecretsReference(encryptedSecretsUrl);
        req.setArgs(args);
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );
        return s_lastRequestId;
    }

    // fulfill the mint request here, invoke the mint
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId);
        }
        s_lastResponse = response;
        s_lastError = err;
        emit FunctionsResponse(requestId, s_lastResponse, s_lastError);

        (string memory cid, string memory name, string memory description, string memory image) = abi.decode(response, (string, string, string, string));

        uint256 newTokenId = _tokenIdCounter + 1;
        _safeMint(msg.sender, newTokenId);
        _tokenIdCounter++;

        _setTokenMetadata(newTokenId, cid, name, description, image);
    }
}