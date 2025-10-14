function toggleComponent(~, ~, ic)
    % 切换选择状态
    selected_components(ic) = ~selected_components(ic);
    
    % 更新显示
    if selected_components(ic)
        set(component_handles(ic), 'Color', 'b');
    else
        set(component_handles(ic), 'Color', 'r');
    end
end