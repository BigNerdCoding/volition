class ReflectionsController < AuthenticatedController
  include ApplicationHelper

  def new
    @reflection = Reflection.new
    @todo_list = current_user.todo_lists.daily.find_by(date: params[:date]) ||
                 TodoList.today(current_user)

    @daily_snapshot = @todo_list.daily_snapshot
    set_link_text_and_url

    if Reflection.today(current_user).present? && reflecting_on_today?
      flash[:error] = 'You already wrote your reflection for today.'
      redirect_to dashboard_path
    elsif TodoList.today(current_user).blank? && reflecting_on_today?
      flash[:error] = 'You must start your tasks for today before writing a reflection.'
      redirect_to dashboard_path
    end
  end

  def create
    @reflection = Reflection.new(reflection_params)
    @reflection.user = current_user

    @todo_list = current_user.todo_lists.daily.find_by(date: reflection_params[:date])
    @todo_list.daily_snapshot&.destroy

    if @reflection.save
      @daily_snapshot = DailySnapshot.create_from_todo_list(@todo_list)

      Todo.where(id: params[:add_to_week]).each do |todo|
        todo.update(
          weekly_todo_list_id: current_week_plan.id,
          daily_todo_list_id: nil
        )
      end

      redirect_to after_create_path
    else
      set_link_text_and_url
      render :new
    end
  end

  private

  def after_create_path
    if @reflection.date != Date.current
      day_path(@daily_snapshot.date)
    elsif tomorrow_is_trackable?
      tomorrow_path
    else
      flash[:success] = 'Nice job today! Get some rest.'
      dashboard_path
    end
  end

  def reflection_params
    params.require(:reflection).permit(
      :rating,
      :positive,
      :negative,
      :undone,
      :date
    )
  end

  def reflecting_on_today?
    @todo_list == TodoList.today(current_user)
  end

  def set_link_text_and_url
    @link_text, @link_url = if reflecting_on_today?
                              ["Go back to today's tasks", today_path]
                            else
                              ["Go back", day_path(@daily_snapshot.date)]
                            end
  end
end
