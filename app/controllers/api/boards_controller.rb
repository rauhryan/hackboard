module Api

  class BoardsController < ApplicationController

    def new

    end

    def update

    end

    def edit

    end

    def show
      board_id = params[:id]
      unless current_user
        render :json => 'ERROR'.to_json
        return
      end
      board = current_user.getBoard(board_id)
      if board
        render :json => current_user.getBoard(board_id).to_json(include: :users)
      else
        render :json => 'ERROR'.to_json
      end
    end

    def index
      if current_user
        data = current_user.myBoards
        response = data.to_json
        render :json => response
        return
      else
        response = 'DAPIE01'
      end
      render :json => response.to_json, :status => :forbidden

    end

    def create
      if current_user
        board = Board.new(:name => 'NewBoard', :wip => '10', :description => 'New Board', :user_id => current_user.id)
        board.save
        board.board_members.create user: current_user

        Flow.create(:name => 'ToDo', order: 1, max_task: 5, max_day: 5, board_id: board.id)
        Flow.create(:name => 'Doing', order: 2, max_task: 5, max_day: 5, board_id: board.id)
        Flow.create(:name => 'Done', order: 3, max_task: 5, max_day: 5, board_id: board.id)

        response = 'success'
        render :json => {
                   :response => response,
                   :board => board
               }.to_json
        return
      else
        response = 'DAPIE02'
      end
      render :json => {:error => response}.to_json, :status => :forbidden
    end

    def destroy
      if current_user
        input = input_params
        board = Board.find(input[:id])
        if board.user_id != current_user.id
          response = 'DAPIE03'
          render :json => response.to_json
          return
        end
        board.destroy
        response = 'delete success'
      else
        response = 'Not login'
        render :json => response.to_json, :status => :unauthorized
        return
      end
      render :json => response.to_json
    end

    def stash
      if current_user
        id = params[:id]
        uuid = params[:uuid]
        stash = params[:stash]


        stash.each do |s|
          if s.key?(:status)
            #   flow
            flow = Flow.find(s[:id].to_i)
            flow.status = "stash"
            flow.save
            render :json => "ok".to_json
            return
          elsif s.key?(:state)
            task = Task.find(s[:id].to_i)
            task.state = "stash"
            task.save
            render :json => "ok".to_json
            return
          end

        end

      end
    end

    def flows
      if current_user
        input = input_params
        board = current_user.getBoard(input[:id])
        member = BoardMember.where(:board_id => board.id, :user_id => current_user.id)
        if board.user_id != current_user.id || !member # if not board owner neither board member
          response = 'DAPIE04'
          render :json => response.to_json
          return
        end
        flows = board.flows.order(:order)
        render :json => flows.to_json(include: [{:tasks => {include: :user}}, {:flows => {include: :tasks, order: :order}}])
        return
      else
        response = 'Not login'
        render :json => response.to_json, :status => :unauthorized
        return
      end
    end

    def add_flow
      if current_user
        uuid = params[:uuid]
        input = input_params


        order = Flow.where({:board_id => input[:id].to_i}).count

        flow = Flow.create(:name => 'New Flow', max_task: 5, max_day: 5, board_id: input[:id], order: order)

        $redis.publish 'hb', {
                               uuid: uuid,
                               type: "flowAdd",
                               board_id: input[:id].to_i,
                               flow: flow
                           }.to_json

        render :json => flow.to_json(include: [:tasks, {:flows => {include: :tasks}}])

      end
    end

    def add_task
      if current_user

        id = params[:id]
        fid = params[:fid]
        uuid = params[:uuid]

        task = Task.create(:state => 'normal',
                           :name => 'new Task',
                           :description => 'new Task',
                           :flow_id => fid)

        $redis.publish 'hb', {
                               uuid: uuid,
                               type: "taskAdd",
                               board_id: id.to_i,
                               task: task
                           }.to_json

        render :json => task.to_json

      end
    end

    def get_task
      if current_user
        render :json => Task::find(params[:id]).to_json
      end
    end

    def add_user
      if current_user

        id = params[:id]
        name = params[:name].to_i

        user = User.find(name)

        if user
          board = Board.find(id)
          unless board.users.include?(user)
            board.users << user
            render json: user.to_json
          end
        end
      end
      render text: ""
    end

    def delete_user

      if current_user

        id = params[:id]
        uid = params[:uid]

        Board.find(id).users.delete(User.find(uid))
        render :json => "ok".to_json
      end

    end

    def update

      if current_user

        # detect which one if change
        # 假設一次只會有一種東西改變

        boardData = params[:board]
        uuid = params[:uuid]

        board = Board.find(boardData[:id])
        id = board.id

        if board.name != boardData[:name] or board.description != boardData[:description]
          board.name = boardData[:name]
          board.description = boardData[:description]
          board.save

          #   send baord change

          $redis.publish 'hb', {
                                 uuid: uuid,
                                 type: "boardChange",
                                 board_id: id,
                                 board: board
                             }.to_json
          render :json => "ok".to_json
          return
        end

        if boardData[:flows]
          boardData[:flows].each do |f|

            flow = Flow.find(f[:id])
            if flow.name != f[:name]
              flow.name = f[:name]
              flow.save
              #   send flow change

              $redis.publish 'hb', {
                                     uuid: uuid,
                                     type: "flowDataChange",
                                     board_id: id,
                                     flow: flow
                                 }.to_json
              render :json => "ok".to_json
              return
            end

            # sub flow not implement
            # if f[:flows]
            #
            #   f[:flows].each do |f2|
            #     flow = Flow.find(f2[:id])
            #     flow.name = f2[:name]
            #     flow.save
            #
            #     if f2[:tasks]
            #       f2oind = 1
            #       f2[:tasks].each do |t2|
            #         task = Task.find(t2[:id])
            #         task.name = t2[:name]
            #         task.order = f2oind
            #         f2oind = f2oind + 1
            #         task.description = t2[:description]
            #         task.flow_id = f2[:id]
            #         task.save
            #       end
            #
            #     end
            #
            #
            #
            #   end
            # end

            if f[:tasks]

              f[:tasks].each do |t1|
                task = Task.find(t1[:id])
                if task.name != t1[:name] or task.description != t1[:description]
                  task.name = t1[:name]
                  task.description = t1[:description]
                  task.save
                  #   send flow change

                  $redis.publish 'hb', {
                                         uuid: uuid,
                                         type: "taskDataChange",
                                         board_id: id,
                                         task: task
                                     }.to_json
                  render :json => "ok".to_json
                  return
                end
              end
            end
          end
        end
        render :json => "ok".to_json
      end
    end

    def update_flow_order
      order = params[:data]
      uuid = params[:uuid]
      ind = 1
      order.each do |i|
        flow = Flow::find(i)
        flow.order = ind
        ind = ind + 1
        flow.save
      end

      $redis.publish 'hb', {
                             uuid: uuid,
                             type: "flowOrderChange",
                             board_id: Flow::find(order[0]).board.id,
                             order: order
                         }.to_json

      render :json => "ok".to_json

    end

    def update_task_order
      order = params[:data]
      id = params[:id]
      uuid = params[:uuid]
      ind = 1
      order.each do |i|
        task = Task::find(i)
        task.order = ind
        ind = ind + 1
        task.save
      end

      $redis.publish 'hb', {
                             uuid: uuid,
                             type: "taskOrderChange",
                             board_id: id.to_i,
                             flow_id: Task.find(order[0]).flow_id,
                             order: order
                         }.to_json
      render :json => "ok".to_json
    end

    def task_move

      board_id = params[:id]
      task_id = params[:taskId]
      sflow = params[:sFlow]
      dflow = params[:dFlow]
      order = params[:order]
      uuid = params[:uuid]

      # move
      task = Task::find(task_id)
      task.flow_id = dflow.to_i
      task.save

      # order
      ind = 1
      order.each do |i|
        task2 = Task::find(i)
        task2.order = ind
        ind = ind + 1
        task2.save
      end

      $redis.publish 'hb', {
                             uuid: uuid,
                             type: "taskMove",
                             board_id: board_id.to_i,
                             task_id: task_id.to_i,
                             sFlow: sflow.to_i,
                             dFlow: dflow.to_i,
                             order: order
                         }.to_json
      render :json => "ok".to_json

    end

    private
    def input_params
      {:id => params.require(:id)}
    end
  end
end