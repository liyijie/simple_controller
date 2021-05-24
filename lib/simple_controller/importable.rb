module SimpleController::Importable
  def upload_excel
    excel = importable_class.import_excel_klass.new
    excel.load(params[:file])
    render json: { uid: excel.uid }
  end

  def excel
    excel = importable_class.import_excel_klass.new(params[:uid])
    pagination = excel.records_pagination(page: params[:page] || 1, per_page: params[:per_page] || 15)
    render json: {
      current_page: pagination.current_page,
      total_pages: pagination.total_pages,
      total_count: pagination.count,
      titles: excel.titles,
      records: pagination,
    }
  end

  def import_headers
    render json: { headers: importable_class.import_instance.import_headers }
  end

  def import
    xlsx_file = params[:file] || importable_class.import_excel_klass.new(params[:uid])
    response = importable_class.import_xlsx(xlsx_file, collection, **params.to_unsafe_h.symbolize_keys)
    render json: response, status: 201
  end
end
