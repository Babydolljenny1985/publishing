// copied from/based on https://observablehq.com/@d3/parallel-sets"
window.Sankey = (function(exports) {
  exports.build = function() {
    const width = 850
        , height = 520
        ;

    var selectedLinkIds = null;

    $data = $('.js-sankey')
    const graph = {
        nodes: $data.data('nodes'),
        links: $data.data('links')
      }
    , numAxes = $data.data('axes')
    ;

    const sankey = d3.sankey()
      .nodeSort(null)
      .linkSort(null)
      .nodeWidth(15)
      .nodePadding(25)
      .extent([[0, 5], [width, height - 20]])
      .nodeId((d) => d.id);

    const svg = d3.select(".js-sankey")
      .append("svg")
      .attr("width", width)
      .style("width", width)
      .attr("height", height)
      .style("height", height)
      .style("margin", "0 auto")
      .style("display", "block")

    const {nodes, links} = sankey({
      nodes: graph.nodes.map(d => Object.assign({}, d)),
      links: graph.links.map(d => Object.assign({}, d))
    });

    const linkDataFn = d3.linkHorizontal()
      .source((d) => [d.source.x1, Math.min(d.source.y1 - (d.width / 2.0), d.y0)])
      .target((d) => [d.target.x0, Math.min(d.target.y1 - (d.width / 2.0), d.y1)]);

    var selectedNodes = {};

    const linkG = svg.append("g")
        .attr("fill", "none");
    addLinks();

    const nodesG = svg.append("g");
    addNodes();

    function handleNodeClick(e, d) {
      if (d.clickable) {
        window.location = d.searchPath;
      }
    }

    function handleNodeMouseenter(e, d) {
      var targetPathLinks = nodeTargetPathLinks(d)
        , sourcePathLinks = nodeSourcePathLinks(d)
        ;

      selectedLinkIds = new Set();

      targetPathLinks.forEach((l) => selectedLinkIds.add(l));
      sourcePathLinks.forEach((l) => selectedLinkIds.add(l));

      updateLinkColors();
    }

    function handleNodeMouseleave() {
      selectedLinkIds = null;
      updateLinkColors();
    }

    // all link uids for paths originating with node n
    function nodeTargetPathLinks(n) {
      return nodePathLinksHelper(new Set([n]), null, 'target');
    } 

    function nodeSourcePathLinks(n) {
      return nodePathLinksHelper(new Set([n]), null, 'source');
    }


    function nodePathLinksHelper(nodes, linkIds, type) {
      if (!linkIds) {
        linkIds = new Set();
      }

      if (!nodes.size) {
        return linkIds;
      }

      const linksKey = type + 'Links'
          , linkNodeKey = type == 'target' ? 'source' : 'target'
          , nextNodes = new Set()
          ;


      nodes.forEach((n) => {
        n[linksKey].forEach((l) => {
          linkIds.add(l.id); 
          nextNodes.add(l[linkNodeKey]);
        });
      });

      return nodePathLinksHelper(nextNodes, linkIds, type);
    }

    function setSelectedNode(node) {
      if (selectedNodes[node.axisId] == node) {
        // unset
        selectedNodes[node.axisId] = null;
      } else {
        //set
        selectedNodes[node.axisId] = node;
      }
    }

    function linkColor(d) {
      if (!selectedLinkIds || selectedLinkIds.has(d.id)) {
        return "#89c783";
      } else {
        return "#eee";
      }
    }

    function addLinks() {
      const link = linkG.selectAll('g')
        .data(links)
        .join('g');

      const gradient = link.append('linearGradient')
        .attr("id", d => d.id)
        .attr('gradientUnits', 'userSpaceOnUse')
        .attr('x1', d => d.source.x1)
        .attr('x2', d => d.target.x0)

      gradient.append('stop')
        .attr('offset', '0%')
        .attr('stop-color', linkColor)
        .attr('stop-opacity', 1);

      gradient.append('stop')
        .attr('offset', '10%')
        .attr('stop-color', linkColor)
        .attr('stop-opacity', 1);

      gradient.append('stop')
        .attr('offset', '30%')
        .attr('stop-color', linkColor)
        .attr('stop-opacity', .5);

      gradient.append('stop')
        .attr('offset', '70%')
        .attr('stop-color', linkColor)
        .attr('stop-opacity', .5);

      gradient.append('stop')
        .attr('offset', '90%')
        .attr('stop-color', linkColor)
        .attr('stop-opacity', 1);

      gradient.append('stop')
        .attr('offset', '100%')
        .attr('stop-color', linkColor)
        .attr('stop-opacity', 1);
        
      link.append('path') 
        .attr("d", linkDataFn)
        .attr("stroke", d => `url(#${d.id})`)
        .attr("stroke-width", d => Math.max(1, d.width));

      link.append("title")
        .text(d => `${d.names.join(" → ")}\n${d.value.toLocaleString()}`)
    }

    function updateLinkColors() {
      if (selectedLinkIds) {
        // put selected links last, i.e., on top
        linkG.selectAll('g').sort((a, b) => {
          if (selectedLinkIds.has(a.id) && !selectedLinkIds.has(b.id)) {
            return 1;
          } else if (!selectedLinkIds.has(a.id) && selectedLinkIds.has(b.id)) {
            return -1;
          } else {
            return 0;
          }
        })
      }

      linkG.selectAll('stop')
        .attr('stop-color', linkColor);
    }

    function addNodes() {
      const nodeG = nodesG.selectAll("g")
        .data(nodes)
        .join("g")
        .on('click', handleNodeClick)
        .on('mouseenter', handleNodeMouseenter)
        .on('mouseleave', handleNodeMouseleave);

      nodeG.append("title")
          .text(d => d.clickable ? d.promptText : null)

      nodeG.append("rect")
          .attr("x", d => d.x0)
          .attr("y", d => d.y0)
          .attr("height", d => d.y1 - d.y0)
          .attr("width", d => d.x1 - d.x0)
          .attr('fill', nodeFillColor)
          .attr('stroke', nodeStrokeColor)
          .attr('stroke-width', nodeStrokeWidth)
          .style('cursor', nodeCursor)
        ;

      nodeG.append("text")
        .style("font", "10px sans-serif")
        .attr("x", d => d.x0 < width / 2 ? d.x1 : d.x0)
        .attr("y", d => d.y1 + 10)
        .attr("dy", "0.35em")
        .attr("text-anchor", d => d.x0 < width / 2 ? "start" : "end")
        .text(d => d.name)
        .style('cursor', nodeCursor)
        .on('mouseenter', handleNodeMouseenter)
        .on('mouseleave', handleNodeMouseleave)
        .append("tspan")
          .attr("fill-opacity", 0.7)
          .text(d => ` ${d.value.toLocaleString()}`);
    }

    function nodeCursor(d) {
      return d.clickable ? 'pointer' : 'normal';
    }

    function nodeFillColor(d) {
      return '#000';
    }

    function nodeStrokeColor(d) {
      return null;
    }

    function nodeStrokeWidth(d) {
      return 0;
    }
  }
  return exports;
})({});
