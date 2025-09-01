module PaginationHelper
  def daisy_pagination(collection)
    return '' unless collection.respond_to?(:current_page)
    
    current = collection.current_page
    total = collection.total_pages
    
    return '' if total <= 1
    
    content_tag :div, class: 'join' do
      links = []
      
      # First page
      if current > 1
        links << link_to(url_for(page: 1), class: 'join-item btn btn-sm') do
          content_tag(:i, '', class: 'fas fa-angle-double-left')
        end
        links << link_to(url_for(page: current - 1), class: 'join-item btn btn-sm') do
          content_tag(:i, '', class: 'fas fa-angle-left')
        end
      else
        links << content_tag(:button, class: 'join-item btn btn-sm btn-disabled', disabled: true) do
          content_tag(:i, '', class: 'fas fa-angle-double-left')
        end
        links << content_tag(:button, class: 'join-item btn btn-sm btn-disabled', disabled: true) do
          content_tag(:i, '', class: 'fas fa-angle-left')
        end
      end
      
      # Page numbers
      (1..total).each do |page|
        if page == 1 || page == total || (page >= current - 2 && page <= current + 2)
          if page == current
            links << content_tag(:button, page.to_s, class: 'join-item btn btn-sm btn-active')
          else
            links << link_to(page.to_s, url_for(page: page), class: 'join-item btn btn-sm')
          end
        elsif page == current - 3 || page == current + 3
          if page == current - 3 && current > 4
            links << content_tag(:button, '...', class: 'join-item btn btn-sm btn-disabled', disabled: true)
          elsif page == current + 3 && current < total - 3
            links << content_tag(:button, '...', class: 'join-item btn btn-sm btn-disabled', disabled: true)
          end
        end
      end
      
      # Last page
      if current < total
        links << link_to(url_for(page: current + 1), class: 'join-item btn btn-sm') do
          content_tag(:i, '', class: 'fas fa-angle-right')
        end
        links << link_to(url_for(page: total), class: 'join-item btn btn-sm') do
          content_tag(:i, '', class: 'fas fa-angle-double-right')
        end
      else
        links << content_tag(:button, class: 'join-item btn btn-sm btn-disabled', disabled: true) do
          content_tag(:i, '', class: 'fas fa-angle-right')
        end
        links << content_tag(:button, class: 'join-item btn btn-sm btn-disabled', disabled: true) do
          content_tag(:i, '', class: 'fas fa-angle-double-right')
        end
      end
      
      safe_join(links)
    end
  end
end