module SimpleController::Importable

  class << self
    def included base
      base.rescue_from TalltyImportExport::Import::RecordNotFountError do |e|
        render json: { message: e.message, code: -1 }, status: 422
      end
    end
  end

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

  # 用 文件 交换信息
  def exchange
    xlsx_file = params[:file] || importable_class.import_excel_klass.new(params[:uid])
    resource_ids = importable_class.exchange_to_ids(xlsx_file, collection, **params.to_unsafe_h.symbolize_keys)
    if params[:return_ids]
      render json: { ids: resource_ids }, status: 200
    else
      respond_with(collection.where(id: resource_ids), { template: "#{self.class.view_path}/index" })
    end
  end
end
