pragma solidity ^0.8.13;

import "solmate/auth/Owned.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ICraftSettlement.sol";
import "./ICraftSettlementRenderer.sol";
import "./CraftSettlementData.sol";

contract CraftSettlementRenderer is Owned, ICraftSettlementRenderer {
    using Strings for uint16;
    using Strings for address;

    string internal constant BASE_STYLES = string(
        abi.encodePacked(
            "@font-face{font-family:Unifont;src:url('https://raw.githubusercontent.com/fontsource/font-files/main/fonts/other/unifont/files/unifont-latin-400-normal.woff');}",
            ".a{width:208px;height:208px;background-color:black;box-sizing:border-box;font-size:16px;font-family:Unifont;display:flex;flex-direction:column;justify-content:center;align-items:center;}",
            "svg{overflow-x:hidden;overflow-y:hidden;margin:0;padding:0;}",
            ".row{height:1rem;}",
            ".t{width:.6rem;display:inline-block;height:1rem;}",
            ".i{font-style:italic;}"
        )
    );
    string internal constant SVG_FOOTER = string(abi.encodePacked("</div>", "</foreignObject>", "</svg>"));

    constructor() Owned(msg.sender) {}

    function renderStylesAndAttributes(address settler, ICraftSettlement settlement, uint16[] memory terrainIdxCount)
        internal
        view
        returns (string memory, string memory)
    {
        // output "attributes" attr
        string memory attributes = "[";
        string memory svgStyles = BASE_STYLES;

        for (uint16 terrainIdx = 0; terrainIdx < terrainIdxCount.length;) {
            if (terrainIdxCount[terrainIdx] > 0) {
                CraftSettlementData.Terrain memory terrain = settlement.getTerrain(terrainIdx);
                svgStyles = string.concat(svgStyles, terrain.styles);
                attributes = string.concat(
                    attributes,
                    '{"trait_type":"',
                    terrain.name,
                    'Count","value":',
                    terrainIdxCount[terrainIdx].toString(),
                    ',"display_type":"number"},'
                );
            }
            unchecked {
                ++terrainIdx;
            }
        }

        attributes = string.concat(attributes, '{"trait_type":"settler","value":"', settler.toHexString(), '"}]');

        return (svgStyles, attributes);
    }

    function renderImage(string[240] memory renderedTerrains, string memory styles)
        internal
        pure
        returns (string memory)
    {
        // output "image" attr
        string memory svg = string.concat(
            "<svg version='2.0' encoding='utf-8' viewBox='0 0 208 208' preserveAspectRatio='xMidYMid' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns='http://www.w3.org/2000/svg'>",
            "<style>",
            styles,
            "</style>",
            "<foreignObject x='0' y='0' width='208' height='208'>",
            "<div class='a' xmlns='http://www.w3.org/1999/xhtml'>"
        );

        for (uint16 i = 0; i < CraftSettlementData.GRID_ROWS;) {
            for (uint16 j = 0; j < 3;) {
                if (j == 0) {
                    svg = string.concat(
                        svg,
                        "<div class='row'>",
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 1],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 2],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 3],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 4],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 5],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 6],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 7]
                    );
                } else if (j == 2) {
                    svg = string.concat(
                        svg,
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 1],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 2],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 3],
                        "</div>"
                    );
                } else {
                    svg = string.concat(
                        svg,
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 1],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 2],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 3],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 4],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 5],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 6],
                        renderedTerrains[i * CraftSettlementData.GRID_COLS + j * 8 + 7]
                    );
                }

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
        svg = string.concat(svg, SVG_FOOTER);
        return svg;
    }

    function render(ICraftSettlement settlement, CraftSettlementData.Metadata memory metadata) public view returns (string memory) {

        // html encoded terrains for token
        string[240] memory renderedTerrains;

        // terrain idx => occurance count within rendered terrains
        uint16[] memory terrainIdxCount = new uint16[](settlement.getTerrainsLength());

        bytes memory seed = CraftSettlementData.getSeedForSettler(metadata.settler);
        for (uint16 i = 0; i < 120;) {
            bytes1 b = seed[i];

            for (uint8 j = 0; j < 2;) {
                uint8 nibble = j == 0 ? uint8(b >> 4) : uint8(b & 0x0F);
                uint16 terrainIdx = metadata.terrainIndexes[(i * 2) + j];
                CraftSettlementData.Terrain memory terrain = settlement.getTerrain(terrainIdx);
                ++terrainIdxCount[terrainIdx];
                renderedTerrains[(i * 2) + j] = terrain.renderedCharacters[nibble % terrain.renderedCharacters.length];

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }

        (string memory styles, string memory attributes) =
            renderStylesAndAttributes(metadata.settler, settlement, terrainIdxCount);

        string memory image = renderImage(renderedTerrains, styles);

        bytes memory dataURI = abi.encodePacked('{"image":"', image, '","attributes":', attributes, "}");

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));

    }

    function tokenURI(address _settlement, uint256 tokenId) external view returns (string memory) {
        ICraftSettlement settlement = ICraftSettlement(_settlement);
        CraftSettlementData.Metadata memory metadata = settlement.getMetadataByTokenId(tokenId);

        return render(settlement, metadata);
    }
}
