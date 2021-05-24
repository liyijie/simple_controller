module SimpleController::Exportable
  def export_headers
    render json: { headers: exportable_class.export_instance.export_headers }
  end

  def export
    path = exportable_class.export_xlsx collection, **params.to_unsafe_h.symbolize_keys
    send_file path
  end
end
