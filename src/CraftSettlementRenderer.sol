pragma solidity ^0.8.13;

import "solmate/auth/Auth.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./CraftSettlement.sol";

contract CraftSettlementRenderer is Auth, ICraftSettlementRenderer {
    using Strings for uint16;
    using Strings for address;

    struct Terrain {
        string name;
        string[] renderedCharacters;
        string styles;
        bool renderCountAttribute;
    }

    string internal constant BASE_STYLES = string(
        abi.encodePacked(
            "@font-face{font-family:Unifont;src:url('https://raw.githubusercontent.com/fontsource/font-files/main/fonts/other/unifont/files/unifont-latin-400-normal.woff');}",
            ".a{width:208px;height:208px;background-color:black;box-sizing:border-box;font-size:16px;font-family:Unifont;display:flex;flex-direction:column;justify-content:center;align-items:center;}",
            "svg{overflow-x:hidden;overflow-y:hidden;margin:0;padding:0;}",
            ".row{height:1rem;}",
            ".t{width:.6rem;display:inline-block;height:1rem;text-align:center;}",
            ".i{font-style:italic;}"
        )
    );
    string internal constant SVG_FOOTER = string(abi.encodePacked("</div>", "</foreignObject>", "</svg>"));

    // Renderable terrains, keyed in metadata by index.
    // Range 0 - 7 inclusive are generated at time of settlement, further terrains
    // are set by event and decision.
    Terrain[] internal terrains;

    CraftSettlement settlement;

    constructor(Authority _authority) Auth(msg.sender, _authority) {
        terrains.push(
            Terrain({
                name: "Grasslands",
                renderedCharacters: new string[](0),
                styles: ".g{color:#6c0;}",
                renderCountAttribute: true
            })
        );
        terrains[0].renderedCharacters.push(renderChar(unicode"ⱱ", "g t"));
        terrains[0].renderedCharacters.push(renderChar(unicode"ⱳ", "g t"));

        terrains.push(
            Terrain({
                name: "Plains",
                renderedCharacters: new string[](0),
                styles: ".p{color:#993;}",
                renderCountAttribute: true
            })
        );
        terrains[1].renderedCharacters.push(renderChar(unicode"ᵥ", "p t"));
        terrains[1].renderedCharacters.push(renderChar(unicode"⩊", "p t"));

        terrains.push(
            Terrain({
                name: "Hills",
                renderedCharacters: new string[](0),
                styles: ".h{color:#630;}",
                renderCountAttribute: true
            })
        );
        terrains[2].renderedCharacters.push(renderChar(unicode"⌒", "h t"));
        terrains[2].renderedCharacters.push(renderChar(unicode"∩", "h t"));

        terrains.push(
            Terrain({
                name: "Mountains",
                renderedCharacters: new string[](0),
                styles: ".m{color:#ccc;}",
                renderCountAttribute: true
            })
        );
        terrains[3].renderedCharacters.push(renderChar(unicode"⋀", "m t"));
        terrains[3].renderedCharacters.push(renderChar(unicode"∆", "m t"));

        terrains.push(
            Terrain({
                name: "Oceans",
                renderedCharacters: new string[](0),
                styles: ".o{color:#00f;}",
                renderCountAttribute: true
            })
        );
        terrains[4].renderedCharacters.push(renderChar(unicode"≈", "o t"));
        terrains[4].renderedCharacters.push(renderChar(unicode"≋", "o t"));

        terrains.push(
            Terrain({
                name: "Woods",
                renderedCharacters: new string[](0),
                styles: ".w{color:#060;}",
                renderCountAttribute: true
            })
        );
        terrains[5].renderedCharacters.push(renderChar(unicode"ᛉ", "w t"));
        terrains[5].renderedCharacters.push(renderChar(unicode"↟", "w t"));

        terrains.push(
            Terrain({
                name: "Rainforests",
                renderedCharacters: new string[](0),
                styles: ".r{color:#9c3;}",
                renderCountAttribute: true
            })
        );
        terrains[6].renderedCharacters.push(renderChar(unicode"ᛉ", "r t"));
        terrains[6].renderedCharacters.push(renderChar(unicode"↟", "r t"));

        terrains.push(
            Terrain({
                name: "Swamps",
                renderedCharacters: new string[](0),
                styles: ".s{color:#3c9;}",
                renderCountAttribute: true
            })
        );
        terrains[7].renderedCharacters.push(renderChar(unicode"„", "s t"));
        terrains[7].renderedCharacters.push(renderChar(unicode"⩫", "s t"));

        terrains.push(
            Terrain({
                name: "Settlement",
                renderedCharacters: new string[](0),
                styles: ".se{color:#630;}",
                renderCountAttribute: false
            })
        );
        terrains[8].renderedCharacters.push(renderChar(unicode"A", "se t"));
    }
    // Render a terrain char into HTML as a classed div

    function renderChar(string memory char, string memory className) internal pure returns (string memory) {
        return string.concat("<div class='", className, "'>", char, "</div>");
    }

    function renderStylesAndAttributes(address settler, CraftSettlement settlement, uint16[] memory terrainCount)
        internal
        view
        returns (string memory, string memory)
    {
        // output "attributes" attr
        string memory attributes = "[";
        string memory svgStyles = BASE_STYLES;

        for (uint16 terrainIdx = 0; terrainIdx < terrainCount.length;) {
            if (terrainCount[terrainIdx] > 0 && terrains[terrainIdx].renderCountAttribute) {
                Terrain memory terrain = terrains[terrainIdx];
                svgStyles = string.concat(svgStyles, terrain.styles);
                attributes = string.concat(
                    attributes,
                    '{"trait_type":"',
                    terrain.name,
                    'Count","value":',
                    terrainCount[terrainIdx].toString(),
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
        view
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

        for (uint16 i = 0; i < settlement.gridRows();) {
            for (uint16 j = 0; j < 3;) {
                if (j == 0) {
                    svg = string.concat(
                        svg,
                        "<div class='row'>",
                        renderedTerrains[i * settlement.gridCols() + j * 8],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 1],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 2],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 3],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 4],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 5],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 6],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 7]
                    );
                } else if (j == 2) {
                    svg = string.concat(
                        svg,
                        renderedTerrains[i * settlement.gridCols() + j * 8],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 1],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 2],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 3],
                        "</div>"
                    );
                } else {
                    svg = string.concat(
                        svg,
                        renderedTerrains[i * settlement.gridCols() + j * 8],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 1],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 2],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 3],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 4],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 5],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 6],
                        renderedTerrains[i * settlement.gridCols() + j * 8 + 7]
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

    function render(CraftSettlement.Metadata memory metadata) public view returns (string memory) {
        // html encoded terrains for token
        string[240] memory renderedTerrains;

        // terrain idx => occurance count within rendered terrains
        uint16[] memory terrainCount = new uint16[](terrains.length);

        bytes memory seed = settlement.getSeedForSettler(metadata.settler);
        for (uint16 i = 0; i < 120;) {
            bytes1 b = seed[i];

            for (uint8 j = 0; j < 2;) {
                uint8 nibble = j == 0 ? uint8(b >> 4) : uint8(b & 0x0F);
                uint16 terrainIdx = metadata.terrains[(i * 2) + j];
                Terrain memory terrain = terrains[terrainIdx];
                ++terrainCount[terrainIdx];
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
            renderStylesAndAttributes(metadata.settler, settlement, terrainCount);

        string memory image = renderImage(renderedTerrains, styles);

        bytes memory dataURI = abi.encodePacked('{"image":"', image, '","attributes":', attributes, "}");

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));
    }

    function setTerrain(uint16 idx, Terrain memory terrain) external requiresAuth {
        require(idx < terrains.length, "idx out of bounds");

        terrains[idx] = terrain;
    }

    function addTerrain(Terrain memory terrain) external requiresAuth {
        terrains.push(terrain);
    }

    function setSettlement(CraftSettlement _settlement) external requiresAuth {
        settlement = _settlement;
    }

    function getTerrainsLength() external view returns (uint256) {
        return terrains.length;
    }

    function getTerrain(uint256 idx) external view returns (Terrain memory) {
        return terrains[idx];
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        CraftSettlement.Metadata memory tokenMetadata = settlement.getMetadataByTokenId(tokenId);

        return render(tokenMetadata);
    }
}
