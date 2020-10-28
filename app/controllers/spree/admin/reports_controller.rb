# frozen_string_literal: true

module Spree
  module Admin
    class ReportsController < Spree::Admin::BaseController
      respond_to :html

      class << self
        def available_reports
          @@available_reports
        end

        def add_available_report!(report_key, report_description_key = nil)
          if report_description_key.nil?
            report_description_key = "#{report_key}_description"
          end

          @@available_reports[report_key] = {
            name: report_key,
            description: report_description_key,
          }
        end
      end

      def initialize
        super
        ReportsController.add_available_report!(:sales_total)
        ReportsController.add_available_report!(:captures_total)

      end

      def index
        @reports = ReportsController.available_reports
      end

      def sales_total
        params[:q] = search_params

        @search = Order.complete.not_canceled.ransack(params[:q])
        @orders = @search.result

        @totals = {}
        @orders.each do |order|
          unless @totals[order.currency]
            @totals[order.currency] = {
              item_total: ::Money.new(0, order.currency),
              adjustment_total: ::Money.new(0, order.currency),
              sales_total: ::Money.new(0, order.currency)
            }
          end

          @totals[order.currency][:item_total] += order.display_item_total.money
          @totals[order.currency][:adjustment_total] += order.display_adjustment_total.money
          @totals[order.currency][:sales_total] += order.display_total.money
        end
      end

      def captures_total
        params[:q] = search_params
        if params[:completed_at_gt].blank?
          params[:completed_at_gt] = 1.day.ago.end_of_day
        else
          params[:completed_at_gt] = Date.strptime(params[:completed_at_gt])
        end

        if params[:completed_at_lt].blank?

          params[:completed_at_lt] = 1.day.from_now.beginning_of_day
        else
          params[:completed_at_lt] = Date.strptime(params[:completed_at_lt])
        end

        @search = Spree::StateChange.where(name: "payment").where(next_state: "completed").where("created_at > ?",params[:completed_at_gt]).where("created_at < ?", params[:completed_at_lt])
        @orders = @search.map{|p| p.stateful&.order }.compact
        @orders.compact!
        @totals = {}
        @orders.each do |order|
          unless @totals[order.currency]
            @totals[order.currency] = {
                item_total: ::Money.new(0, order.currency),
                adjustment_total: ::Money.new(0, order.currency),
                sales_total: ::Money.new(0, order.currency)
            }
          end
          @totals[order.currency][:sales_total] += order.display_total.money
        end
      end

      @@available_reports = {}

      private

      def search_params
        params.fetch(:q, {}).tap do |q|
          q[:completed_at_gt] = adjust_start_date q[:completed_at_gt]
          q[:completed_at_lt] = adjust_end_date(q[:completed_at_lt]) if q[:completed_at_lt].present?
          q[:s] ||= 'completed_at desc'
        end
      end

      def adjust_start_date(string_date = nil)
        return Time.current.beginning_of_month if string_date.blank?

        Time.zone.parse(string_date).beginning_of_day
      rescue ArgumentError
        Time.current.beginning_of_month
      end

      def adjust_end_date(string_date)
        Time.zone.parse(string_date).end_of_day
      rescue ArgumentError
        ""
      end
    end
  end
end
