function polygon = Read_shapefile( finputname, bbox, min_length, ...
                                   h0, plot_on, polygon )
% Read_shapefile: Reads a shapefile polygon on the coastline, extracting
% the desired area out, and making the open ocean boundaries automatically

% finputname : file name(s) of the shapefile
% bbox    : the bounding box that we want to extract out
% min_length : minimum length of points in polygon to accept 
% plot_on :  plot the final polygon or not (=1 or =0)
    
%% Loop over all the filenames and get the shapefile within bbox
SG = [];
for fname = finputname
    % Read the structure
    S = shaperead(fname{1},'BoundingBox',bbox');
 
    % Get rid of unwanted components
    F = fieldnames(S);
    D = struct2cell(S);
    S = cell2struct(D(3:4,:), F(3:4));
    
    if ~isempty(S)
        % Keep the following polygons
        SG = [SG; S];
    end
end

% If we don't have an outer polygon already then make it by bbox
if isempty(polygon)
    polygon.outer = [bbox(1,1) bbox(2,1);
                     bbox(1,1) bbox(2,2);
                     bbox(1,2) bbox(2,2);
                     bbox(1,2) bbox(2,1);
                     bbox(1,1) bbox(2,1)];
end
% Densify the outer polygon (fills gaps larger than half min edgelength).
[latout,lonout] = interpm(polygon.outer(:,2),...
                          polygon.outer(:,1),h0/2);
polygon.outer = [];
polygon.outer(:,1) = lonout;
polygon.outer(:,2) = latout;

%% Find whether the polygons are wholey inside the bbox.. 
%% Set as islands or mainland
polygon.inner = [];
polygon.mainland = [];
edges = Get_poly_edges( [polygon.outer;NaN NaN] );
% if isempty(gcp)
%     parpool('local',num_p);
% end
% Pool = gcp('nocreate');
for s = 1:length(SG)
    % Get current polygon
    x_n = SG(s).X; y_n = SG(s).Y;
    x_n = x_n(~isnan(x_n)); y_n = y_n(~isnan(y_n));
    % Check proportion of polygon that is within bbox
    In = inpoly([x_n',y_n'],[polygon.outer;NaN NaN],edges);
%     
    
    % Get the average distance between points in polygon
    m_d = mean(abs(diff([x_n; y_n],[],2)),2); m_d = norm(m_d,2);
    % instead of basing this on length, lets calculate the area of the
    % feature using the shoelace algorithm and decided whether to keep or
    % not based on area. 
    if(x_n(end)==x_n(1))
        area = shoelace(x_n',y_n');
        %area 
        %hold on; plot(x_n,y_n,'r'); 
    else 
        area = 999; % not a polygon
    end
    if(area < 4*h0^2) % too small don't consider it.
    %if length(find(In == 1)) < h0/m_d*min_length
        % If length of polygon within bbox is too small then we ignore it
        continue;
    elseif length(find(In == 1)) == length(x_n)
        % Wholey inside box, set as island
        new_island = [SG(s).X' SG(s).Y'];
        polygon.inner = [polygon.inner; new_island];   
    else
        % Partially inside box, set as mainland
        new_main = [SG(s).X' SG(s).Y'];
        polygon.mainland = [polygon.mainland; new_main]; 
    end
end
% Add mainland to outer polygon to get full outer polygon
polygon.outer = [polygon.outer; NaN NaN; polygon.mainland]; 

%% Plot the map
if plot_on >= 1 && ~isempty(polygon)
    figure(1);
    hold on
    plot(polygon.outer(:,1),polygon.outer(:,2))
    if ~isempty(polygon.inner)
        plot(polygon.inner(:,1),polygon.inner(:,2))
    end
    if ~isempty(polygon.mainland)
        plot(polygon.mainland(:,1),polygon.mainland(:,2))
    end
end
%EOF
end

%% Legacy shit
%     nn = 0; I = []; L = 0;
%     for s = 1:length(S)
%         x_n = S(s).X; y_n = S(s).Y; 
%         x_n = x_n(~isnan(x_n)); y_n = y_n(~isnan(y_n));
%         m_d = mean(abs(diff([x_n; y_n],[],2)),2); m_d = norm(m_d,2);
%         % Ignore small length shapes
%         if length(x_n) < h0/m_d*min_length; continue; end
%         if any(x_n > bbox(1,1)) && any(x_n < bbox(1,2)) && ...
%            any(y_n > bbox(2,1)) && any(y_n < bbox(2,2))   
%            % Make sure we also ignore the shapes where the length of 
%            % the array thats within bbox is small
%            xtemp = get_x_y_in_bbox(S(s),bbox);
%            if length(xtemp) < h0/m_d*min_length; continue; end
%            nn = nn + 1;
%            I(nn) = s;
%            L = length(xtemp) + L;
%         end
%     end

% end
% polygon.outer = []; 
% end_e = 2;
% % Get the starting lb for the longest shape within bbox
% mL = 0;
% for lbt = 1:length(lb_v)
%     X_n = get_x_y_in_bbox(SG(lb_v(lbt)),bbox);
%     if length(X_n) > mL
%         lb = lbt;
%     end
% end
% while ~isempty(lb_v)
%     X_n = get_x_y_in_bbox(SG(lb_v(lb)),bbox);
%     if isempty(X_n)
%         lb_v(lb) = [];
%         continue; 
%     end
%     if end_e == 1
%         % add to the mainland boundary
%         polygon.mainland = [polygon.mainland; X_n; NaN NaN]; 
%         % add to the outer polygon                
%         polygon.outer = [polygon.outer; X_n];   
%     elseif end_e == 2
%         % add to the mainland boundary
%         polygon.mainland = [polygon.mainland; flipud(X_n); NaN NaN]; 
%         % add to the outer polygon                
%         polygon.outer = [polygon.outer; flipud(X_n)];
%     end
%     % delete this boundary
%     lb_v(lb) = [];             
%     % now we need to draw the open boundary
%     % find the current edge number, = 1 top, = 2 right, =3 bottom, = 4 left
%     edge = find_edge_num(polygon.outer(end,:),bbox);
%     e_vec = edge:4;
%     if edge <= 4; e_vec = [e_vec, 1:edge-1]; end
%     % now find closest node near edge going around in clockwise direction
%     dist = 9e6;
%     for e = e_vec
%         found = 0; delete = 0;
%         for llb = 1:length(lb_v)
%             X_n = get_x_y_in_bbox(SG(lb_v(llb)),bbox);
%             if isempty(X_n)
%                 delete = llb;
%                 continue; 
%             end
%             se = find_edge_num(X_n(1,:),bbox);
%             ee = find_edge_num(X_n(end,:),bbox);
%             if se == e
%                found = 1;
%                d_n = distance(X_n(1,2),X_n(1,1),...
%                               polygon.outer(end,2),polygon.outer(end,1));
%                if d_n < dist
%                     lb = llb; end_e = 1; dist = d_n;
%                end
%             end
%             if ee == e
%                found = 1;
%                d_n = distance(X_n(end,2),X_n(end,1),...
%                               polygon.outer(end,2),polygon.outer(end,1));
%                if d_n < dist
%                     lb = llb; end_e = 2; dist = d_n;
%                end
%             end
%         end
%         if delete > 0
%             lb_v(delete) = [];
%         end
%         if found
%             break; 
%         else
%             ee = find_edge_num(polygon.outer(1,:),bbox);
%             if isempty(lb_v) && ee == e
%                 % set the first point to close polygon
%                 polygon.outer(end+1,:) = polygon.outer(1,:);
%                 break;
%             else
%                 % start a new edge so need to add the the next corner in
%                 segment = add_corner(polygon.outer(end,:),e,bbox,h0);
%                 polygon.outer(end+1:end+length(segment),:) = segment;
%             end
%         end
%     end
% end  
% if isempty(polygon.outer)
%    % Just join the four points
%    polygon.outer = [bbox(1,2) bbox(2,2);
%               bbox(1,2) bbox(2,1);
%               bbox(1,1) bbox(2,1);
%               bbox(1,1) bbox(2,2);
%               bbox(1,2) bbox(2,2)]; 
% end
% 
% function X_n = get_x_y_in_bbox(SG,bbox)
%     X_n(:,1) = SG.X'; X_n(:,2) = SG.Y';
%     I = find(X_n(:,1) > bbox(1,1) & X_n(:,1) < bbox(1,2) & ...
%              X_n(:,2) > bbox(2,1) & X_n(:,2) < bbox(2,2));
%     X_n = X_n(I,:);
%     if length(I) < 2; return; end
%     % Find the points that are close to an edge and re-sort if necessary
%     is = [];
%     m_d = mean(abs(diff(X_n))); m_d = norm(m_d,2);
%     for i = 1:length(X_n)
%         [~,d] = find_edge_num(X_n(i,:),bbox);
%         if d < 2*m_d
%            is = [is i];
%         end
%     end
%     if ~isempty(is)
%         % only re-sort if all points are not equal to 1 and X_n
%         if ~any(is == 1) && ~any(is == length(X_n))
%             X_n = X_n([is:end 1:is-1],:);
%         end
%     end
% end
% 
% function [edge,d] = find_edge_num(node,bbox)
% % find the current edge number, = 1 top, = 2 right, =3 bottom, = 4 left
% 	[d,edge] = min([bbox(2,2) - node(2);...
%                    bbox(1,2) - node(1); ...
%                    node(2) - bbox(2,1);...
%                    node(1) - bbox(1,1)]);
% end
% 
% function corner = add_corner(poly_end,e,bbox,h0)
% % find the current edge number, = 1 top, = 2 right, =3 bottom, = 4 left
%     if e == 1
%         num = abs(poly_end(1) - bbox(1,2))/h0;
%         corner(:,1) = linspace(poly_end(1),bbox(1,2),num);
%         %corner(:,1) = poly_end(1)-h0:-h0:bbox(1,2); 
%         corner(end,1) = bbox(1,2); corner(:,2) = bbox(2,2);
%         %corner = [bbox(1,2) bbox(2,2)];
%     elseif e == 2
%         %corner(:,2) = poly_end(2)+h0:h0:bbox(2,1); 
%         num = abs(poly_end(2) - bbox(2,1))/h0;
%         corner(:,2) = linspace(poly_end(2),bbox(2,1),num); 
%         corner(end,2) = bbox(2,1); corner(:,1) = bbox(1,2); 
%         %corner = [bbox(1,2) bbox(2,1)];
%     elseif e == 3
%         num = abs(poly_end(1) - bbox(1,1))/h0;
%         corner(:,1) = linspace(poly_end(1),bbox(1,1),num); 
%         %corner(:,1) = poly_end(1)+h0:h0:bbox(1,1); 
%         corner(end,1) = bbox(1,1);
%         corner(:,2) = bbox(2,1);
%         %corner = [bbox(1,1) bbox(2,1)];
%     elseif e == 4
%         num = abs(poly_end(2) - bbox(2,2))/h0;
%         corner(:,2) = linspace(poly_end(2),bbox(2,2),num); 
%         %corner(:,2) = poly_end(2)-h0:-h0:bbox(2,2); 
%         corner(end,2) = bbox(2,2); corner(:,1) = bbox(1,1); 
%         %corner = [bbox(1,1) bbox(2,2)]; 
%     end
%     
% end
% 
% function d = find_distance_to_corner(nodes,bbox)
% % set up the corners
%     corners = [bbox(1,2) bbox(2,2);
%               bbox(1,2) bbox(2,1);
%               bbox(1,1) bbox(2,1);
%               bbox(1,1) bbox(2,2)]; 
% % get nearest distances
%     [~,d] = knnsearch(corners,nodes);     
%end

